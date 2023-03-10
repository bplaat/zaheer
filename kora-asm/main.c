/*
### Kora Assembler ###
Made by Bastiaan van der Plaat

Work in progress!!!

TODO items:
- all instructions
- org, equ vars, $, labels, .labels
- db dw dd times align
- + - * / % & | ^ ~ ( )
- good error messaging
- basic disassembler
*/

#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Kora constants
typedef enum KoraReg {
    KORA_REG_T0,
    KORA_REG_T1,
    KORA_REG_T2,
    KORA_REG_T3,
    KORA_REG_T4,
    KORA_REG_S0,
    KORA_REG_S1,
    KORA_REG_S2,
    KORA_REG_S3,
    KORA_REG_A0,
    KORA_REG_A1,
    KORA_REG_A2,
    KORA_REG_A3,
    KORA_REG_BP,
    KORA_REG_SP,
    KORA_REG_FLAGS
} KoraReg;

KoraReg string_to_reg(char *reg) {
    if (!strcmp(reg, "t0")) return KORA_REG_T0;
    if (!strcmp(reg, "t1")) return KORA_REG_T1;
    if (!strcmp(reg, "t2")) return KORA_REG_T2;
    if (!strcmp(reg, "t3")) return KORA_REG_T3;
    if (!strcmp(reg, "t4")) return KORA_REG_T4;
    if (!strcmp(reg, "s0")) return KORA_REG_S0;
    if (!strcmp(reg, "s1")) return KORA_REG_S1;
    if (!strcmp(reg, "s2")) return KORA_REG_S2;
    if (!strcmp(reg, "s3")) return KORA_REG_S3;
    if (!strcmp(reg, "a0")) return KORA_REG_A0;
    if (!strcmp(reg, "a1")) return KORA_REG_A1;
    if (!strcmp(reg, "a2")) return KORA_REG_A2;
    if (!strcmp(reg, "a3")) return KORA_REG_A3;
    if (!strcmp(reg, "bp")) return KORA_REG_BP;
    if (!strcmp(reg, "sp")) return KORA_REG_SP;
    if (!strcmp(reg, "flags")) return KORA_REG_FLAGS;
    return -1;
}

char *reg_to_string(uint8_t reg) {
    if (reg == KORA_REG_T0) return "t0";
    if (reg == KORA_REG_T1) return "t1";
    if (reg == KORA_REG_T2) return "t2";
    if (reg == KORA_REG_T3) return "t3";
    if (reg == KORA_REG_T4) return "t4";
    if (reg == KORA_REG_S0) return "s0";
    if (reg == KORA_REG_S1) return "s1";
    if (reg == KORA_REG_S2) return "s2";
    if (reg == KORA_REG_S3) return "s3";
    if (reg == KORA_REG_A0) return "a0";
    if (reg == KORA_REG_A1) return "a1";
    if (reg == KORA_REG_A2) return "a2";
    if (reg == KORA_REG_A3) return "a3";
    if (reg == KORA_REG_BP) return "bp";
    if (reg == KORA_REG_SP) return "sp";
    if (reg == KORA_REG_FLAGS) return "flags";
    return NULL;
}

typedef enum KoraCond {
    KORA_COND_ALWAYS,
    KORA_COND_NEVER,
    KORA_COND_Z,
    KORA_COND_NZ,
    KORA_COND_S,
    KORA_COND_NS,
    KORA_COND_C,
    KORA_COND_NC,
    KORA_COND_O,
    KORA_COND_NO,
    KORA_COND_A,
    KORA_COND_NA,
    KORA_COND_L,
    KORA_COND_NL,
    KORA_COND_G,
    KORA_COND_NG
} KoraCond;

typedef enum KoraOpcode {
    KORA_OP_MOV,
    KORA_OP_LW,
    KORA_OP_LH,
    KORA_OP_LHSX,
    KORA_OP_LB,
    KORA_OP_LBSX,
    KORA_OP_SW,
    KORA_OP_SH,
    KORA_OP_SB,

    KORA_OP_ADD,
    KORA_OP_ADC,
    KORA_OP_SUB,
    KORA_OP_SBB,
    KORA_OP_NEG,
    KORA_OP_CMP,

    KORA_OP_AND,
    KORA_OP_OR,
    KORA_OP_XOR,
    KORA_OP_NOT,
    KORA_OP_TEST,
    KORA_OP_SHL,
    KORA_OP_SHR,
    KORA_OP_SAR,

    KORA_OP_JMP,

    KORA_OP_PUSH,
    KORA_OP_POP,
    KORA_OP_CALL,
    KORA_OP_RET
} KoraOpcode;

KoraOpcode string_to_opcode(char *reg) {
    if (!strcmp(reg, "mov")) return KORA_OP_MOV;
    if (!strcmp(reg, "lw")) return KORA_OP_LW;
    if (!strcmp(reg, "lh")) return KORA_OP_LH;
    if (!strcmp(reg, "lhsx")) return KORA_OP_LHSX;
    if (!strcmp(reg, "lb")) return KORA_OP_LB;
    if (!strcmp(reg, "lbsx")) return KORA_OP_LBSX;
    if (!strcmp(reg, "sw")) return KORA_OP_SW;
    if (!strcmp(reg, "sh")) return KORA_OP_SH;
    if (!strcmp(reg, "sb")) return KORA_OP_SB;

    if (!strcmp(reg, "add")) return KORA_OP_ADD;
    if (!strcmp(reg, "adc")) return KORA_OP_ADC;
    if (!strcmp(reg, "sub")) return KORA_OP_SUB;
    if (!strcmp(reg, "sbb")) return KORA_OP_SBB;
    if (!strcmp(reg, "neg")) return KORA_OP_NEG;
    if (!strcmp(reg, "cmp")) return KORA_OP_CMP;

    if (!strcmp(reg, "and")) return KORA_OP_AND;
    if (!strcmp(reg, "or")) return KORA_OP_OR;
    if (!strcmp(reg, "xor")) return KORA_OP_XOR;
    if (!strcmp(reg, "not")) return KORA_OP_NOT;
    if (!strcmp(reg, "test")) return KORA_OP_TEST;
    if (!strcmp(reg, "shl")) return KORA_OP_SHL;
    if (!strcmp(reg, "shr")) return KORA_OP_SHR;
    if (!strcmp(reg, "sar")) return KORA_OP_SAR;

    if (!strcmp(reg, "jmp")) return KORA_OP_JMP;
    // if (!strcmp(reg, "jz")) return KORA_OP_JZ;
    // if (!strcmp(reg, "jnz")) return KORA_OP_JNZ;
    // if (!strcmp(reg, "js")) return KORA_OP_JS;
    // if (!strcmp(reg, "jns")) return KORA_OP_JNS;
    // if (!strcmp(reg, "jc")) return KORA_OP_JC;
    // if (!strcmp(reg, "jnc")) return KORA_OP_JNC;
    // if (!strcmp(reg, "jo")) return KORA_OP_JO;
    // if (!strcmp(reg, "jno")) return KORA_OP_JNO;
    // if (!strcmp(reg, "ja")) return KORA_OP_JA;
    // if (!strcmp(reg, "jna")) return KORA_OP_JNA;
    // if (!strcmp(reg, "jb")) return KORA_OP_JB;
    // if (!strcmp(reg, "jnb")) return KORA_OP_JNB;
    // if (!strcmp(reg, "jl")) return KORA_OP_JL;
    // if (!strcmp(reg, "jml")) return KORA_OP_JNL;
    // if (!strcmp(reg, "jg")) return KORA_OP_JG;
    // if (!strcmp(reg, "jng")) return KORA_OP_JNG;

    if (!strcmp(reg, "push")) return KORA_OP_PUSH;
    if (!strcmp(reg, "pop")) return KORA_OP_POP;
    if (!strcmp(reg, "call")) return KORA_OP_CALL;
    if (!strcmp(reg, "ret")) return KORA_OP_RET;
    return -1;
}

typedef enum KoraMode { KORA_MODE_REG_SMALL, KORA_MODE_REG_LARGE, KORA_MODE_IMM_SMALL, KORA_MODE_IMM_LARGE } KoraMode;

// Utils

// Lexer

char *token_type_to_string(TokenType type) {
    if (type == TOKEN_EOF) return "EOF";
    if (type == TOKEN_KEYWORD) return "keyword";
    if (type == TOKEN_NUMBER) return "number";
    if (type == TOKEN_COLON) return ":";
    if (type == TOKEN_COMMA) return ",";
    if (type == TOKEN_LBRACKET) return "[";
    if (type == TOKEN_RBRACKET) return "]";
    if (type == TOKEN_ADD) return "+";
    if (type == TOKEN_SUB) return "-";
    return NULL;
}

bool lexer(char *text, Token *tokens, size_t *tokens_size) {
    char *c = text;
    size_t size = 0;
    while (*c != '\0') {
        if (*c == ';' || *c == '#' || (*c == '/' && *(c + 1) == '/')) {
            while (*c != '\r' && *c != '\n') {
                if (*c == '\n') c++;
                c++;
            }
            continue;
        }

        if (*c == '0' && *(c + 1) == 'b') {
            c += 2;
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 2);
            continue;
        }
        if (*c == '0' && *(c + 1) == 'x') {
            c += 2;
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 16);
            continue;
        }
        if (*c == '0') {
            c++;
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 8);
            continue;
        }
        if (isdigit(*c)) {
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 10);
            continue;
        }

        if (isalpha(*c)) {
            char *string_ptr = c;
            while (isalnum(*c)) c++;
            size_t string_size = c - string_ptr;
            char *string = malloc(string_size + 1);
            memcpy(string, string_ptr, string_size);
            string[string_size] = '\0';
            tokens[size].type = TOKEN_KEYWORD;
            tokens[size++].string = string;
            continue;
        }

        if (*c == ':') {
            c++;
            tokens[size++].type = TOKEN_COLON;
            continue;
        }
        if (*c == ',') {
            c++;
            tokens[size++].type = TOKEN_COMMA;
            continue;
        }
        if (*c == '[') {
            c++;
            tokens[size++].type = TOKEN_LBRACKET;
            continue;
        }
        if (*c == ']') {
            c++;
            tokens[size++].type = TOKEN_RBRACKET;
            continue;
        }
        if (*c == '+') {
            c++;
            tokens[size++].type = TOKEN_ADD;
            continue;
        }
        if (*c == '-') {
            c++;
            tokens[size++].type = TOKEN_SUB;
            continue;
        }

        if (isspace(*c)) {
            c++;
            continue;
        }

        fprintf(stderr, "Unknown character: %c\n", *c);
        return false;
    }
    tokens[size++].type = TOKEN_EOF;
    *tokens_size = size;
    return true;
}

// Parser
typedef struct Opcode {
    char *name;
    KoraOpcode opcode;
} Opcode;

Opcode opcodes[] = {
    {"mov", KORA_OP_MOV}, {"add", KORA_OP_ADD}, {"adc", KORA_OP_ADC}, {"sub", KORA_OP_SUB},
    {"sbb", KORA_OP_SBB}, {"neg", KORA_OP_NEG}, {"cmp", KORA_OP_CMP}, {"and", KORA_OP_AND},
    {"or", KORA_OP_OR},   {"xor", KORA_OP_XOR}, {"not", KORA_OP_NOT}, {"test", KORA_OP_TEST},
    {"shl", KORA_OP_SHL}, {"shr", KORA_OP_SHR}, {"sar", KORA_OP_SAR}

    // KORA_OP_LW,
    // KORA_OP_LH,
    // KORA_OP_LHSX,
    // KORA_OP_LB,
    // KORA_OP_LBSX,
    // KORA_OP_SW,
    // KORA_OP_SH,
    // KORA_OP_SB,

};

int main(int argc, char **argv) {
    if (argc == 1) {
        printf("Kora Assembler\n");
        return EXIT_SUCCESS;
    }

    char *text = file_read(argv[1]);

    // Lexer
    Token tokens[512];
    size_t tokens_size = 0;
    if (!lexer(text, tokens, &tokens_size)) {
        return EXIT_FAILURE;
    }

    printf("Tokens: ");
    for (size_t i = 0; i < tokens_size; i++) {
        printf("%s ", token_type_to_string(tokens[i].type));
    }
    printf("\n");

    // Parser
    uint8_t output[512];
    size_t output_size = 0;

    size_t pos = 0;
    for (;;) {
        if (tokens[pos].type == TOKEN_EOF) {
            break;
        }

        if (tokens[pos].type == TOKEN_KEYWORD) {
            KoraOpcode opcode = string_to_opcode(tokens[pos].string);

            if (opcode == KORA_OP_POP) {
                pos++;
                if (tokens[pos].type == TOKEN_KEYWORD) {
                    uint8_t dest = string_to_reg(tokens[pos++].string);
                    output[output_size++] = (opcode << 2) | KORA_MODE_REG_SMALL;
                    output[output_size++] = dest;
                    continue;
                }
            }

            else if (opcode >= KORA_OP_JMP || opcode == KORA_OP_PUSH ||
                     opcode == KORA_OP_CALL || opcode == KORA_OP_RET) {
                pos++;
                if (tokens[pos].type == TOKEN_KEYWORD) {
                    uint8_t src = string_to_reg(tokens[pos++].string);
                    output[output_size++] = (opcode << 2) | KORA_MODE_REG_SMALL;
                    output[output_size++] = src;
                    continue;
                }
                if (tokens[pos].type == TOKEN_NUMBER) {
                    uint32_t imm = tokens[pos++].number;
                    if (opcode == KORA_OP_JMP || opcode == KORA_OP_CALL) {
                        imm >>= 1;
                    }
                    if (imm < 16) {
                        output[output_size++] = (opcode << 2) | KORA_MODE_IMM_SMALL;
                        output[output_size++] = imm;
                    } else {
                        output[output_size++] = (opcode << 2) | KORA_MODE_IMM_LARGE;
                        output[output_size++] = (imm & 0xf);
                        output[output_size++] = (imm >> 4) & 0xff;
                        output[output_size++] = (imm >> 12) & 0xff;
                    }
                    continue;
                }
            }

            else {
                bool done = false;
                for (size_t i = 0; i < sizeof(opcodes) / sizeof(Opcode); i++) {
                    Opcode *opcode = &opcodes[i];
                    if (!strcmp(tokens[pos].string, opcode->name)) {
                        pos++;
                        uint8_t dest = string_to_reg(tokens[pos++].string);
                        pos++;  // comma

                        if (tokens[pos].type == TOKEN_KEYWORD) {
                            uint8_t src = string_to_reg(tokens[pos++].string);
                            output[output_size++] = (opcode->opcode << 2) | KORA_MODE_REG_SMALL;
                            output[output_size++] = (dest << 4) | src;
                        } else {
                            uint32_t imm = tokens[pos++].number;
                            if (opcode->opcode == KORA_OP_SHL || opcode->opcode == KORA_OP_SHR ||
                                opcode->opcode == KORA_OP_SAR) {
                                imm--;
                            }
                            if (imm < 16) {
                                output[output_size++] = (opcode->opcode << 2) | KORA_MODE_IMM_SMALL;
                                output[output_size++] = (dest << 4) | imm;
                            } else {
                                output[output_size++] = (opcode->opcode << 2) | KORA_MODE_IMM_LARGE;
                                output[output_size++] = (dest << 4) | (imm & 0xf);
                                output[output_size++] = (imm >> 4) & 0xff;
                                output[output_size++] = (imm >> 12) & 0xff;
                            }
                        }
                        done = true;
                        break;
                    }
                }
                if (done) {
                    continue;
                }
            }
        }

        fprintf(stderr, "Unexpected token: %s\n", token_type_to_string(tokens[pos].type));
        exit(EXIT_FAILURE);
    }

    // Output
    printf("Output:\n");
    for (size_t i = 0; i < output_size; i++) {
        printf("%02x", output[i]);
        if (i != 0 && i % 8 == 0) {
            printf("\n");
        } else {
            printf(" ");
        }
    }
    return EXIT_SUCCESS;
}
