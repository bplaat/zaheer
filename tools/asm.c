/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

// Basic RV32I assembler - outputs 32-bit hex words (one per line)
// Supports: all RV32I instructions, common pseudo-instructions,
// %hi/%lo relocations, labels, and basic directives.

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LINES 4096
#define MAX_LABELS 1024
#define MAX_EQUS 256
#define MAX_LINE_LEN 512
#define MAX_OUTPUT 16384

// Output buffer (byte-level, emitted as 32-bit words at the end)
static uint8_t output[MAX_OUTPUT];
static int output_pos = 0;

// Labels
static struct {
    char name[64];
    uint32_t addr;
} labels[MAX_LABELS];
static int label_count = 0;

// .equ constants
static struct {
    char name[64];
    int32_t value;
} equs[MAX_EQUS];
static int equ_count = 0;

// Source lines
static char lines[MAX_LINES][MAX_LINE_LEN];
static int line_count = 0;

static int current_line = 0;
static int pass = 0;  // 0 = collect labels, 1 = emit code

static void error(const char* msg) {
    fprintf(stderr, "Error on line %d: %s\n", current_line + 1, msg);
    fprintf(stderr, "  %s\n", lines[current_line]);
    exit(1);
}

static void error_msg(const char* msg, const char* detail) {
    fprintf(stderr, "Error on line %d: %s '%s'\n", current_line + 1, msg, detail);
    fprintf(stderr, "  %s\n", lines[current_line]);
    exit(1);
}

// Emit helpers
static void emit_byte(uint8_t b) {
    if (output_pos >= MAX_OUTPUT)
        error("output buffer overflow");
    if (pass == 1)
        output[output_pos] = b;
    output_pos++;
}

static void emit_word(uint32_t w) {
    emit_byte(w & 0xFF);
    emit_byte((w >> 8) & 0xFF);
    emit_byte((w >> 16) & 0xFF);
    emit_byte((w >> 24) & 0xFF);
}

static void align_to(int alignment) {
    while (output_pos % alignment != 0)
        emit_byte(0);
}

// Label lookup
static int find_label(const char* name, uint32_t* addr) {
    for (int i = 0; i < label_count; i++) {
        if (strcmp(labels[i].name, name) == 0) {
            *addr = labels[i].addr;
            return 1;
        }
    }
    return 0;
}

static void add_label(const char* name, uint32_t addr) {
    if (label_count >= MAX_LABELS)
        error("too many labels");
    strncpy(labels[label_count].name, name, 63);
    labels[label_count].name[63] = '\0';
    labels[label_count].addr = addr;
    label_count++;
}

// .equ lookup
static int find_equ(const char* name, int32_t* value) {
    for (int i = 0; i < equ_count; i++) {
        if (strcmp(equs[i].name, name) == 0) {
            *value = equs[i].value;
            return 1;
        }
    }
    return 0;
}

static void add_equ(const char* name, int32_t value) {
    if (equ_count >= MAX_EQUS)
        error("too many .equ definitions");
    strncpy(equs[equ_count].name, name, 63);
    equs[equ_count].name[63] = '\0';
    equs[equ_count].value = value;
    equ_count++;
}

// String trimming
static char* trim(char* s) {
    while (isspace((unsigned char)*s))
        s++;
    char* end = s + strlen(s) - 1;
    while (end > s && isspace((unsigned char)*end))
        *end-- = '\0';
    return s;
}

// Register name to number
static int parse_reg(const char* s) {
    if (!s || !*s)
        error("expected register");

    // x0-x31
    if (s[0] == 'x' && isdigit((unsigned char)s[1])) {
        int r = atoi(s + 1);
        if (r >= 0 && r <= 31)
            return r;
    }

    // ABI names
    if (strcmp(s, "zero") == 0)
        return 0;
    if (strcmp(s, "ra") == 0)
        return 1;
    if (strcmp(s, "sp") == 0)
        return 2;
    if (strcmp(s, "gp") == 0)
        return 3;
    if (strcmp(s, "tp") == 0)
        return 4;
    if (strcmp(s, "fp") == 0)
        return 8;

    // t0-t6
    if (s[0] == 't' && isdigit((unsigned char)s[1]) && s[2] == '\0') {
        int n = s[1] - '0';
        if (n <= 2)
            return 5 + n;  // t0=x5, t1=x6, t2=x7
        if (n <= 6)
            return 28 + (n - 3);  // t3=x28..t6=x31
    }

    // s0-s11
    if (s[0] == 's' && isdigit((unsigned char)s[1])) {
        int n = atoi(s + 1);
        if (n == 0)
            return 8;
        if (n == 1)
            return 9;
        if (n >= 2 && n <= 11)
            return 18 + (n - 2);
    }

    // a0-a7
    if (s[0] == 'a' && isdigit((unsigned char)s[1]) && s[2] == '\0') {
        int n = s[1] - '0';
        if (n <= 7)
            return 10 + n;
    }

    error_msg("unknown register", s);
    return 0;
}

// Parse an immediate value, handling %hi(), %lo(), labels, .equ, and hex/dec
static int32_t parse_imm(const char* s) {
    if (!s || !*s)
        error("expected immediate");

    // %hi(value)
    if (strncmp(s, "%hi(", 4) == 0) {
        char inner[128];
        strncpy(inner, s + 4, sizeof(inner) - 1);
        inner[sizeof(inner) - 1] = '\0';
        char* paren = strchr(inner, ')');
        if (paren)
            *paren = '\0';
        int32_t val = parse_imm(inner);
        // Upper 20 bits, adjusted for sign extension of lo12
        return ((uint32_t)(val + 0x800) >> 12) & 0xFFFFF;
    }

    // %lo(value)
    if (strncmp(s, "%lo(", 4) == 0) {
        char inner[128];
        strncpy(inner, s + 4, sizeof(inner) - 1);
        inner[sizeof(inner) - 1] = '\0';
        char* paren = strchr(inner, ')');
        if (paren)
            *paren = '\0';
        int32_t val = parse_imm(inner);
        // Sign-extended lower 12 bits
        int32_t lo = val & 0xFFF;
        if (lo & 0x800)
            lo |= ~0xFFF;
        return lo;
    }

    // Hex
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
        return (int32_t)strtoul(s, NULL, 16);

    // Negative number
    if (s[0] == '-' && isdigit((unsigned char)s[1]))
        return (int32_t)strtol(s, NULL, 10);

    // Decimal number
    if (isdigit((unsigned char)s[0]))
        return (int32_t)strtol(s, NULL, 10);

    // .equ constant
    int32_t equ_val;
    if (find_equ(s, &equ_val))
        return equ_val;

    // Label (address)
    uint32_t addr;
    if (find_label(s, &addr))
        return (int32_t)addr;

    if (pass == 0)
        return 0;  // Labels may not be defined yet in pass 0

    error_msg("unknown symbol", s);
    return 0;
}

// Tokenize a line into parts (splits on commas and whitespace)
// Returns tokens and count; handles offset(reg) syntax
static char tokens[16][128];
static int token_count;

static void tokenize(char* line) {
    token_count = 0;
    char* p = line;

    while (*p && token_count < 16) {
        while (isspace((unsigned char)*p) || *p == ',')
            p++;
        if (!*p || *p == '#' || *p == '/')
            break;

        char* start = p;

        // Handle parenthesized expressions like 0(t0) -> "0" "t0"
        // But also handle %hi(...) and %lo(...) as single tokens
        if (*p == '%' || *p == '-' || isdigit((unsigned char)*p)) {
            // Check if this is %hi( or %lo( -> capture the whole thing
            if (*p == '%') {
                while (*p && *p != ')')
                    p++;
                if (*p == ')')
                    p++;
                int len = (int)(p - start);
                strncpy(tokens[token_count], start, len);
                tokens[token_count][len] = '\0';
                token_count++;
                continue;
            }

            // Number possibly followed by (reg)
            while (*p && !isspace((unsigned char)*p) && *p != ',' && *p != '(')
                p++;

            if (*p == '(') {
                // offset(reg) - emit offset as one token, reg as another
                int len = (int)(p - start);
                strncpy(tokens[token_count], start, len);
                tokens[token_count][len] = '\0';
                token_count++;
                p++;  // skip '('
                start = p;
                while (*p && *p != ')')
                    p++;
                len = (int)(p - start);
                strncpy(tokens[token_count], start, len);
                tokens[token_count][len] = '\0';
                token_count++;
                if (*p == ')')
                    p++;
                continue;
            }
        } else {
            // Regular token
            while (*p && !isspace((unsigned char)*p) && *p != ',' && *p != '(')
                p++;
            if (*p == '(') {
                // label(reg) style - shouldn't normally happen for RV32I
                int len = (int)(p - start);
                strncpy(tokens[token_count], start, len);
                tokens[token_count][len] = '\0';
                token_count++;
                p++;
                start = p;
                while (*p && *p != ')')
                    p++;
                int len2 = (int)(p - start);
                strncpy(tokens[token_count], start, len2);
                tokens[token_count][len2] = '\0';
                token_count++;
                if (*p == ')')
                    p++;
                continue;
            }
        }

        int len = (int)(p - start);
        if (len > 0) {
            strncpy(tokens[token_count], start, len);
            tokens[token_count][len] = '\0';
            token_count++;
        }
    }
}

// Instruction encoding helpers
static uint32_t enc_r(int funct7, int rs2, int rs1, int funct3, int rd, int opcode) {
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) |
           ((rd & 0x1F) << 7) | (opcode & 0x7F);
}

static uint32_t enc_i(int imm, int rs1, int funct3, int rd, int opcode) {
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F);
}

static uint32_t enc_s(int imm, int rs2, int rs1, int funct3, int opcode) {
    return (((imm >> 5) & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) |
           ((imm & 0x1F) << 7) | (opcode & 0x7F);
}

static uint32_t enc_b(int imm, int rs2, int rs1, int funct3) {
    int imm12 = (imm >> 12) & 1;
    int imm10_5 = (imm >> 5) & 0x3F;
    int imm4_1 = (imm >> 1) & 0xF;
    int imm11 = (imm >> 11) & 1;
    return (imm12 << 31) | (imm10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) |
           (imm4_1 << 8) | (imm11 << 7) | 0x63;
}

static uint32_t enc_u(int imm, int rd, int opcode) {
    return ((imm & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F);
}

static uint32_t enc_j(int imm, int rd) {
    int imm20 = (imm >> 20) & 1;
    int imm10_1 = (imm >> 1) & 0x3FF;
    int imm11 = (imm >> 11) & 1;
    int imm19_12 = (imm >> 12) & 0xFF;
    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | ((rd & 0x1F) << 7) | 0x6F;
}

// Process one assembly line
static void process_line(char* raw_line) {
    char line[MAX_LINE_LEN];
    strncpy(line, raw_line, MAX_LINE_LEN - 1);
    line[MAX_LINE_LEN - 1] = '\0';

    // Strip comments (//, #, and ;)
    char* comment = strstr(line, "//");
    if (comment)
        *comment = '\0';
    comment = strchr(line, '#');
    if (comment)
        *comment = '\0';
    comment = strchr(line, ';');
    if (comment)
        *comment = '\0';

    char* trimmed = trim(line);
    if (!*trimmed)
        return;

    // Handle labels (word followed by ':')
    char* colon = strchr(trimmed, ':');
    if (colon && colon > trimmed) {
        // Check it's a valid label (no spaces before colon)
        int is_label = 1;
        for (char* c = trimmed; c < colon; c++) {
            if (isspace((unsigned char)*c)) {
                is_label = 0;
                break;
            }
        }
        if (is_label) {
            *colon = '\0';
            if (pass == 0)
                add_label(trimmed, output_pos);
            trimmed = trim(colon + 1);
            if (!*trimmed)
                return;
        }
    }

    tokenize(trimmed);
    if (token_count == 0)
        return;

    char* mnem = tokens[0];

    // Directives
    if (strcmp(mnem, ".section") == 0 || strcmp(mnem, ".globl") == 0 || strcmp(mnem, ".global") == 0 ||
        strcmp(mnem, ".type") == 0) {
        return;  // Ignored
    }

    if (strcmp(mnem, ".equ") == 0) {
        if (token_count < 3)
            error(".equ requires name and value");
        if (pass == 0)
            add_equ(tokens[1], parse_imm(tokens[2]));
        return;
    }

    if (strcmp(mnem, ".align") == 0) {
        if (token_count < 2)
            error(".align requires argument");
        int a = atoi(tokens[1]);
        align_to(1 << a);
        return;
    }

    if (strcmp(mnem, ".balign") == 0) {
        if (token_count < 2)
            error(".balign requires argument");
        int a = atoi(tokens[1]);
        align_to(a);
        return;
    }

    if (strcmp(mnem, ".byte") == 0) {
        for (int i = 1; i < token_count; i++)
            emit_byte((uint8_t)parse_imm(tokens[i]));
        return;
    }

    if (strcmp(mnem, ".half") == 0) {
        for (int i = 1; i < token_count; i++) {
            uint16_t v = (uint16_t)parse_imm(tokens[i]);
            emit_byte(v & 0xFF);
            emit_byte((v >> 8) & 0xFF);
        }
        return;
    }

    if (strcmp(mnem, ".word") == 0) {
        for (int i = 1; i < token_count; i++)
            emit_word((uint32_t)parse_imm(tokens[i]));
        return;
    }

    if (strcmp(mnem, ".ascii") == 0 || strcmp(mnem, ".asciz") == 0) {
        // Find the string in the raw line
        char* q = strchr(raw_line, '"');
        if (!q)
            error("expected quoted string");
        q++;
        while (*q && *q != '"') {
            if (*q == '\\') {
                q++;
                switch (*q) {
                    case 'n':
                        emit_byte('\n');
                        break;
                    case 'r':
                        emit_byte('\r');
                        break;
                    case 't':
                        emit_byte('\t');
                        break;
                    case '\\':
                        emit_byte('\\');
                        break;
                    case '"':
                        emit_byte('"');
                        break;
                    case '0':
                        emit_byte('\0');
                        break;
                    default:
                        emit_byte(*q);
                        break;
                }
            } else {
                emit_byte(*q);
            }
            q++;
        }
        if (strcmp(mnem, ".asciz") == 0)
            emit_byte(0);
        return;
    }

    if (strcmp(mnem, ".zero") == 0) {
        if (token_count < 2)
            error(".zero requires size");
        int n = atoi(tokens[1]);
        for (int i = 0; i < n; i++)
            emit_byte(0);
        return;
    }

    // Pseudo-instructions
    if (strcmp(mnem, "nop") == 0) {
        emit_word(enc_i(0, 0, 0, 0, 0x13));  // addi x0, x0, 0
        return;
    }

    if (strcmp(mnem, "li") == 0) {
        if (token_count < 3)
            error("li requires rd, imm");
        int rd = parse_reg(tokens[1]);
        int32_t imm = parse_imm(tokens[2]);
        if (imm >= -2048 && imm <= 2047) {
            emit_word(enc_i(imm, 0, 0, rd, 0x13));  // addi rd, x0, imm
        } else {
            uint32_t hi = ((uint32_t)(imm + 0x800) >> 12) & 0xFFFFF;
            int32_t lo = imm - (int32_t)(hi << 12);
            emit_word(enc_u(hi, rd, 0x37));  // lui rd, hi
            if (lo != 0)
                emit_word(enc_i(lo & 0xFFF, rd, 0, rd, 0x13));  // addi rd, rd, lo
        }
        return;
    }

    if (strcmp(mnem, "la") == 0) {
        if (token_count < 3)
            error("la requires rd, symbol");
        int rd = parse_reg(tokens[1]);
        int32_t addr = parse_imm(tokens[2]);
        uint32_t pc_val = output_pos;
        int32_t offset = addr - (int32_t)pc_val;
        uint32_t hi = ((uint32_t)(offset + 0x800) >> 12) & 0xFFFFF;
        int32_t lo = offset - (int32_t)(hi << 12);
        emit_word(enc_u(hi, rd, 0x17));                 // auipc rd, hi
        emit_word(enc_i(lo & 0xFFF, rd, 0, rd, 0x13));  // addi rd, rd, lo
        return;
    }

    if (strcmp(mnem, "mv") == 0) {
        if (token_count < 3)
            error("mv requires rd, rs");
        int rd = parse_reg(tokens[1]);
        int rs = parse_reg(tokens[2]);
        emit_word(enc_i(0, rs, 0, rd, 0x13));  // addi rd, rs, 0
        return;
    }

    if (strcmp(mnem, "not") == 0) {
        if (token_count < 3)
            error("not requires rd, rs");
        int rd = parse_reg(tokens[1]);
        int rs = parse_reg(tokens[2]);
        emit_word(enc_i(-1, rs, 4, rd, 0x13));  // xori rd, rs, -1
        return;
    }

    if (strcmp(mnem, "neg") == 0) {
        if (token_count < 3)
            error("neg requires rd, rs");
        int rd = parse_reg(tokens[1]);
        int rs = parse_reg(tokens[2]);
        emit_word(enc_r(0x20, rs, 0, 0, rd, 0x33));  // sub rd, x0, rs
        return;
    }

    if (strcmp(mnem, "seqz") == 0) {
        int rd = parse_reg(tokens[1]);
        int rs = parse_reg(tokens[2]);
        emit_word(enc_i(1, rs, 3, rd, 0x13));  // sltiu rd, rs, 1
        return;
    }

    if (strcmp(mnem, "snez") == 0) {
        int rd = parse_reg(tokens[1]);
        int rs = parse_reg(tokens[2]);
        emit_word(enc_r(0, rs, 0, 3, rd, 0x33));  // sltu rd, x0, rs
        return;
    }

    if (strcmp(mnem, "ret") == 0) {
        emit_word(enc_i(0, 1, 0, 0, 0x67));  // jalr x0, ra, 0
        return;
    }

    if (strcmp(mnem, "call") == 0) {
        if (token_count < 2)
            error("call requires symbol");
        int32_t target = parse_imm(tokens[1]);
        int32_t offset = target - (int32_t)output_pos;
        uint32_t hi = ((uint32_t)(offset + 0x800) >> 12) & 0xFFFFF;
        int32_t lo = offset - (int32_t)(hi << 12);
        emit_word(enc_u(hi, 1, 0x17));                // auipc ra, hi
        emit_word(enc_i(lo & 0xFFF, 1, 0, 1, 0x67));  // jalr ra, ra, lo
        return;
    }

    if (strcmp(mnem, "j") == 0) {
        if (token_count < 2)
            error("j requires target");
        int32_t target = parse_imm(tokens[1]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_j(offset, 0));  // jal x0, offset
        return;
    }

    if (strcmp(mnem, "jr") == 0) {
        if (token_count < 2)
            error("jr requires rs");
        int rs = parse_reg(tokens[1]);
        emit_word(enc_i(0, rs, 0, 0, 0x67));  // jalr x0, rs, 0
        return;
    }

    // Branch pseudo-instructions
    if (strcmp(mnem, "beqz") == 0) {
        int rs = parse_reg(tokens[1]);
        int32_t target = parse_imm(tokens[2]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_b(offset, 0, rs, 0));  // beq rs, x0, offset
        return;
    }
    if (strcmp(mnem, "bnez") == 0) {
        int rs = parse_reg(tokens[1]);
        int32_t target = parse_imm(tokens[2]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_b(offset, 0, rs, 1));
        return;
    }
    if (strcmp(mnem, "blez") == 0) {
        int rs = parse_reg(tokens[1]);
        int32_t target = parse_imm(tokens[2]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_b(offset, rs, 0, 5));  // bge x0, rs, offset
        return;
    }
    if (strcmp(mnem, "bgez") == 0) {
        int rs = parse_reg(tokens[1]);
        int32_t target = parse_imm(tokens[2]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_b(offset, 0, rs, 5));  // bge rs, x0, offset
        return;
    }
    if (strcmp(mnem, "bltz") == 0) {
        int rs = parse_reg(tokens[1]);
        int32_t target = parse_imm(tokens[2]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_b(offset, 0, rs, 4));  // blt rs, x0, offset
        return;
    }
    if (strcmp(mnem, "bgtz") == 0) {
        int rs = parse_reg(tokens[1]);
        int32_t target = parse_imm(tokens[2]);
        int32_t offset = target - (int32_t)output_pos;
        emit_word(enc_b(offset, rs, 0, 4));  // blt x0, rs, offset
        return;
    }

    // R-type instructions
    struct {
        const char* name;
        int funct7;
        int funct3;
    } r_insns[] = {{"add", 0x00, 0},  {"sub", 0x20, 0}, {"sll", 0x00, 1}, {"slt", 0x00, 2},
                   {"sltu", 0x00, 3}, {"xor", 0x00, 4}, {"srl", 0x00, 5}, {"sra", 0x20, 5},
                   {"or", 0x00, 6},   {"and", 0x00, 7}, {NULL, 0, 0}};
    for (int i = 0; r_insns[i].name; i++) {
        if (strcmp(mnem, r_insns[i].name) == 0) {
            if (token_count < 4)
                error("R-type requires rd, rs1, rs2");
            int rd = parse_reg(tokens[1]);
            int rs1 = parse_reg(tokens[2]);
            int rs2 = parse_reg(tokens[3]);
            emit_word(enc_r(r_insns[i].funct7, rs2, rs1, r_insns[i].funct3, rd, 0x33));
            return;
        }
    }

    // I-type ALU instructions
    struct {
        const char* name;
        int funct3;
    } i_alu[] = {{"addi", 0}, {"slti", 2}, {"sltiu", 3}, {"xori", 4}, {"ori", 6}, {"andi", 7}, {NULL, 0}};
    for (int i = 0; i_alu[i].name; i++) {
        if (strcmp(mnem, i_alu[i].name) == 0) {
            if (token_count < 4)
                error("I-type ALU requires rd, rs1, imm");
            int rd = parse_reg(tokens[1]);
            int rs1 = parse_reg(tokens[2]);
            int32_t imm = parse_imm(tokens[3]);
            emit_word(enc_i(imm, rs1, i_alu[i].funct3, rd, 0x13));
            return;
        }
    }

    // Shift immediate instructions
    if (strcmp(mnem, "slli") == 0) {
        int rd = parse_reg(tokens[1]);
        int rs1 = parse_reg(tokens[2]);
        int shamt = parse_imm(tokens[3]) & 0x1F;
        emit_word(enc_i(shamt, rs1, 1, rd, 0x13));
        return;
    }
    if (strcmp(mnem, "srli") == 0) {
        int rd = parse_reg(tokens[1]);
        int rs1 = parse_reg(tokens[2]);
        int shamt = parse_imm(tokens[3]) & 0x1F;
        emit_word(enc_i(shamt, rs1, 5, rd, 0x13));
        return;
    }
    if (strcmp(mnem, "srai") == 0) {
        int rd = parse_reg(tokens[1]);
        int rs1 = parse_reg(tokens[2]);
        int shamt = parse_imm(tokens[3]) & 0x1F;
        emit_word(enc_i(0x400 | shamt, rs1, 5, rd, 0x13));
        return;
    }

    // Load instructions
    struct {
        const char* name;
        int funct3;
    } loads[] = {{"lb", 0}, {"lh", 1}, {"lw", 2}, {"lbu", 4}, {"lhu", 5}, {NULL, 0}};
    for (int i = 0; loads[i].name; i++) {
        if (strcmp(mnem, loads[i].name) == 0) {
            // Format: lw rd, offset(rs1) -> tokens: lw rd offset rs1
            if (token_count < 4)
                error("load requires rd, offset(rs1)");
            int rd = parse_reg(tokens[1]);
            int32_t offset = parse_imm(tokens[2]);
            int rs1 = parse_reg(tokens[3]);
            emit_word(enc_i(offset, rs1, loads[i].funct3, rd, 0x03));
            return;
        }
    }

    // Store instructions
    struct {
        const char* name;
        int funct3;
    } stores[] = {{"sb", 0}, {"sh", 1}, {"sw", 2}, {NULL, 0}};
    for (int i = 0; stores[i].name; i++) {
        if (strcmp(mnem, stores[i].name) == 0) {
            // Format: sw rs2, offset(rs1) -> tokens: sw rs2 offset rs1
            if (token_count < 4)
                error("store requires rs2, offset(rs1)");
            int rs2 = parse_reg(tokens[1]);
            int32_t offset = parse_imm(tokens[2]);
            int rs1 = parse_reg(tokens[3]);
            emit_word(enc_s(offset, rs2, rs1, stores[i].funct3, 0x23));
            return;
        }
    }

    // Branch instructions
    struct {
        const char* name;
        int funct3;
    } branches[] = {{"beq", 0}, {"bne", 1}, {"blt", 4}, {"bge", 5}, {"bltu", 6}, {"bgeu", 7}, {NULL, 0}};
    for (int i = 0; branches[i].name; i++) {
        if (strcmp(mnem, branches[i].name) == 0) {
            if (token_count < 4)
                error("branch requires rs1, rs2, target");
            int rs1 = parse_reg(tokens[1]);
            int rs2 = parse_reg(tokens[2]);
            int32_t target = parse_imm(tokens[3]);
            int32_t offset = target - (int32_t)output_pos;
            emit_word(enc_b(offset, rs2, rs1, branches[i].funct3));
            return;
        }
    }

    // LUI
    if (strcmp(mnem, "lui") == 0) {
        if (token_count < 3)
            error("lui requires rd, imm");
        int rd = parse_reg(tokens[1]);
        int32_t imm = parse_imm(tokens[2]);
        emit_word(enc_u(imm, rd, 0x37));
        return;
    }

    // AUIPC
    if (strcmp(mnem, "auipc") == 0) {
        if (token_count < 3)
            error("auipc requires rd, imm");
        int rd = parse_reg(tokens[1]);
        int32_t imm = parse_imm(tokens[2]);
        emit_word(enc_u(imm, rd, 0x17));
        return;
    }

    // JAL
    if (strcmp(mnem, "jal") == 0) {
        if (token_count == 2) {
            // jal target (rd = ra)
            int32_t target = parse_imm(tokens[1]);
            int32_t offset = target - (int32_t)output_pos;
            emit_word(enc_j(offset, 1));
        } else if (token_count >= 3) {
            // jal rd, target
            int rd = parse_reg(tokens[1]);
            int32_t target = parse_imm(tokens[2]);
            int32_t offset = target - (int32_t)output_pos;
            emit_word(enc_j(offset, rd));
        } else {
            error("jal requires target");
        }
        return;
    }

    // JALR
    if (strcmp(mnem, "jalr") == 0) {
        if (token_count == 2) {
            // jalr rs1 (rd = ra, offset = 0)
            int rs1 = parse_reg(tokens[1]);
            emit_word(enc_i(0, rs1, 0, 1, 0x67));
        } else if (token_count >= 4) {
            // jalr rd, rs1, offset  OR  jalr rd, offset(rs1)
            int rd = parse_reg(tokens[1]);
            int32_t offset = parse_imm(tokens[2]);
            int rs1 = parse_reg(tokens[3]);
            emit_word(enc_i(offset, rs1, 0, rd, 0x67));
        } else if (token_count == 3) {
            // jalr rd, rs1 (offset = 0)
            int rd = parse_reg(tokens[1]);
            int rs1 = parse_reg(tokens[2]);
            emit_word(enc_i(0, rs1, 0, rd, 0x67));
        } else {
            error("jalr requires arguments");
        }
        return;
    }

    // FENCE
    if (strcmp(mnem, "fence") == 0) {
        emit_word(0x0000000F);
        return;
    }

    // ECALL / EBREAK
    if (strcmp(mnem, "ecall") == 0) {
        emit_word(0x00000073);
        return;
    }
    if (strcmp(mnem, "ebreak") == 0) {
        emit_word(0x00100073);
        return;
    }

    error_msg("unknown instruction", mnem);
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <input.s> [output.mem]\n", argv[0]);
        return 1;
    }

    FILE* fin = fopen(argv[1], "r");
    if (!fin) {
        fprintf(stderr, "Cannot open input file: %s\n", argv[1]);
        return 1;
    }

    // Read all lines
    while (fgets(lines[line_count], MAX_LINE_LEN, fin)) {
        // Remove trailing newline
        char* nl = strchr(lines[line_count], '\n');
        if (nl)
            *nl = '\0';
        nl = strchr(lines[line_count], '\r');
        if (nl)
            *nl = '\0';
        line_count++;
        if (line_count >= MAX_LINES) {
            fprintf(stderr, "Too many lines\n");
            fclose(fin);
            return 1;
        }
    }
    fclose(fin);

    // Pass 0: collect labels
    pass = 0;
    output_pos = 0;
    for (current_line = 0; current_line < line_count; current_line++)
        process_line(lines[current_line]);

    // Pass 1: emit code
    pass = 1;
    output_pos = 0;
    for (current_line = 0; current_line < line_count; current_line++)
        process_line(lines[current_line]);

    // Pad to word boundary
    while (output_pos % 4 != 0)
        output[output_pos++] = 0;

    // Output
    FILE* fout = stdout;
    if (argc >= 3) {
        fout = fopen(argv[2], "w");
        if (!fout) {
            fprintf(stderr, "Cannot open output file: %s\n", argv[2]);
            return 1;
        }
    }

    int word_count = output_pos / 4;
    // Pad to at least 1024 words (4KB ROM)
    int min_words = 1024;
    for (int i = 0; i < word_count || i < min_words; i++) {
        if (i < word_count) {
            uint32_t w =
                output[i * 4] | (output[i * 4 + 1] << 8) | (output[i * 4 + 2] << 16) | (output[i * 4 + 3] << 24);
            fprintf(fout, "%08x\n", w);
        } else {
            fprintf(fout, "00000000\n");
        }
    }

    if (fout != stdout)
        fclose(fout);

    return 0;
}
