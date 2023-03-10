#include "lexer.h"

#include <stdio.h>
#include <stdlib.h>

// Source
NblSource *nbl_source_new(char *path, char *text) {
    NblSource *source = malloc(sizeof(NblSource));
    source->refs = 1;
    source->path = strdup(path);
    source->text = strdup(text);

    // Reverse loop over path to find basename
    char *c = source->path + strlen(source->path);
    while (*c != '/' && c != source->path) c--;
    source->basename = c + 1;

    source->dirname = strndup(source->path, source->basename - 1 - source->path);
    return source;
}

NblSource *nbl_source_ref(NblSource *source) {
    source->refs++;
    return source;
}

void nbl_source_get_line_column(NblSource *source, int32_t offset, int32_t *_line, int32_t *_column,
                                char **_lineStart) {
    int32_t line = 1;
    int32_t column = 1;
    char *lineStart = source->text;
    char *c = source->text;
    while (*c) {
        if (c - source->text == offset) {
            break;
        }
        if (*c == '\r' || *c == '\n') {
            column = 1;
            line++;
            if (*c == '\r') c++;
            c++;
            lineStart = c;
        } else {
            column++;
            c++;
        }
    }
    *_line = line;
    *_column = column;
    *_lineStart = lineStart;
}

void nbl_source_print_error(NblSource *source, int32_t offset, char *format, ...) {
    int32_t line;
    int32_t column;
    char *lineStart;
    nbl_source_get_line_column(source, offset, &line, &column, &lineStart);

    fprintf(stderr, "%s:%d:%d ERROR: ", source->path, line, column);
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);

    char *c = lineStart;
    while (*c != '\n' && *c != '\r' && *c != '\0') c++;
    size_t lineLength = c - lineStart;

    fprintf(stderr, "\n%4d | ", line);
    fwrite(lineStart, 1, lineLength, stderr);
    fprintf(stderr, "\n     | ");
    for (int32_t i = 0; i < column - 1; i++) fprintf(stderr, " ");
    fprintf(stderr, "^\n");
}

void nbl_source_release(NblSource *source) {
    source->refs--;
    if (source->refs > 0) return;

    free(source->path);
    free(source->dirname);
    free(source->text);
    free(source);
}

// Token
char *token_type_to_string(TokenType type) {
    if (type == TOKEN_EOF) return "eof";
    if (type == TOKEN_NUMBER) return "number";
    if (type == TOKEN_VARIABLE) return "variable";
    if (type == TOKEN_STRING) return "string";

    // Operators
    if (type == TOKEN_COLON) return ":";
    if (type == TOKEN_COMMA) return ",";
    if (type == TOKEN_LBRACKET) return "[";
    if (type == TOKEN_RBRACKET) return "]";
    if (type == TOKEN_LPAREN) return "(";
    if (type == TOKEN_RPAREN) return ")";
    if (type == TOKEN_ASSIGN) return "=";
    if (type == TOKEN_ADD) return "+";
    if (type == TOKEN_SUB) return "-";
    if (type == TOKEN_MUL) return "*";
    if (type == TOKEN_DIV) return "/";
    if (type == TOKEN_MOD) return "%";
    if (type == TOKEN_AND) return "&";
    if (type == TOKEN_OR) return "|";
    if (type == TOKEN_XOR) return "^";
    if (type == TOKEN_NOT) return "~";
    if (type == TOKEN_SHL) return "<<";
    if (type == TOKEN_SHR) return ">>";

    // Keywords
    if (type == TOKEN_DB) return "db";
    if (type == TOKEN_DH) return "dh";
    if (type == TOKEN_DW) return "dw";
    if (type == TOKEN_TIMES) return "times";
    if (type == TOKEN_ALIGN) return "align";
    if (type == TOKEN_BYTE) return "byte";
    if (type == TOKEN_HALF) return "half";
    if (type == TOKEN_WORD) return "word";

    // Registers
    if (type == TOKEN_T0) return "t0";
    if (type == TOKEN_T1) return "t1";
    if (type == TOKEN_T2) return "t2";
    if (type == TOKEN_T3) return "t3";
    if (type == TOKEN_T4) return "t4";
    if (type == TOKEN_S0) return "s0";
    if (type == TOKEN_S1) return "s1";
    if (type == TOKEN_S2) return "s2";
    if (type == TOKEN_S3) return "s3";
    if (type == TOKEN_A0) return "a0";
    if (type == TOKEN_A1) return "a1";
    if (type == TOKEN_A2) return "a2";
    if (type == TOKEN_A3) return "a3";
    if (type == TOKEN_BP) return "bp";
    if (type == TOKEN_SP) return "sp";
    if (type == TOKEN_FLAGS) return "flags";

    // Opcodes
    if (type == TOKEN_MOV) return "mov";
    if (type == TOKEN_MOVSX) return "movsx";
    if (type == TOKEN_LW) return "lw";
    if (type == TOKEN_LH) return "lh";
    if (type == TOKEN_LHSX) return "lhsx";
    if (type == TOKEN_LB) return "lb";
    if (type == TOKEN_LBSX) return "lbsx";
    if (type == TOKEN_SW) return "sw";
    if (type == TOKEN_SH) return "sh";
    if (type == TOKEN_SB) return "sb";
    if (type == TOKEN_ADD) return "add";
    if (type == TOKEN_ADC) return "adc";
    if (type == TOKEN_SUB) return "sub";
    if (type == TOKEN_SBB) return "sbb";
    if (type == TOKEN_NEG) return "neg";
    if (type == TOKEN_CMP) return "cmp";
    if (type == TOKEN_AND) return "and";
    if (type == TOKEN_OR) return "or";
    if (type == TOKEN_XOR) return "xor";
    if (type == TOKEN_NOT) return "not";
    if (type == TOKEN_TEST) return "test";
    if (type == TOKEN_SHL) return "shl";
    if (type == TOKEN_SHR) return "shr";
    if (type == TOKEN_SAR) return "sar";
    if (type == TOKEN_JMP) return "jmp";
    if (type == TOKEN_JZ) return "jz";
    if (type == TOKEN_JNZ) return "jnz";
    if (type == TOKEN_JS) return "js";
    if (type == TOKEN_JNS) return "jns";
    if (type == TOKEN_JC) return "jc";
    if (type == TOKEN_JNC) return "jnc";
    if (type == TOKEN_JO) return "jo";
    if (type == TOKEN_JNO) return "jno";
    if (type == TOKEN_JA) return "ja";
    if (type == TOKEN_JNA) return "jna";
    if (type == TOKEN_JL) return "jl";
    if (type == TOKEN_JNL) return "jnl";
    if (type == TOKEN_JG) return "jg";
    if (type == TOKEN_JNG) return "jng";
    if (type == TOKEN_PUSH) return "push";
    if (type == TOKEN_POP) return "pop";
    if (type == TOKEN_CALL) return "call";
    if (type == TOKEN_RET) return "ret";
    if (type == TOKEN_INC) return "inc";
    if (type == TOKEN_DEC) return "dec";
    return NULL;
}

void token_free(Token *token) {
    if (token->type == TOKEN_VARIABLE || token->type == TOKEN_STRING) {
        free(token->string);
    }
}

Keyword keywords[] = {
    {TOKEN_DB, "db"},       {TOKEN_DH, "dh"},     {TOKEN_DW, "dw"},     {TOKEN_TIMES, "times"}, {TOKEN_ALIGN, "align"},
    {TOKEN_BYTE, "byte"},   {TOKEN_HALF, "half"}, {TOKEN_WORD, "word"}, {TOKEN_T0, "t0"},       {TOKEN_T1, "t1"},
    {TOKEN_T2, "t2"},       {TOKEN_T3, "t3"},     {TOKEN_T4, "t4"},     {TOKEN_S0, "s0"},       {TOKEN_S1, "s1"},
    {TOKEN_S2, "s2"},       {TOKEN_S3, "s3"},     {TOKEN_A0, "a0"},     {TOKEN_A1, "a1"},       {TOKEN_A2, "a2"},
    {TOKEN_A3, "a3"},       {TOKEN_BP, "bp"},     {TOKEN_SP, "sp"},     {TOKEN_FLAGS, "flags"}, {TOKEN_MOV, "mov"},
    {TOKEN_MOVSX, "movsx"}, {TOKEN_LW, "lw"},     {TOKEN_LH, "lh"},     {TOKEN_LHSX, "lhsx"},   {TOKEN_LB, "lb"},
    {TOKEN_LBSX, "lbsx"},   {TOKEN_SW, "sw"},     {TOKEN_SH, "sh"},     {TOKEN_SB, "sb"},       {TOKEN_ADD, "add"},
    {TOKEN_ADC, "adc"},     {TOKEN_SUB, "sub"},   {TOKEN_SBB, "sbb"},   {TOKEN_NEG, "neg"},     {TOKEN_CMP, "cmp"},
    {TOKEN_AND, "and"},     {TOKEN_OR, "or"},     {TOKEN_XOR, "xor"},   {TOKEN_NOT, "not"},     {TOKEN_TEST, "test"},
    {TOKEN_SHL, "shl"},     {TOKEN_SHR, "shr"},   {TOKEN_SAR, "sar"},   {TOKEN_JMP, "jmp"},     {TOKEN_JZ, "jz"},
    {TOKEN_JNZ, "jnz"},     {TOKEN_JS, "js"},     {TOKEN_JNS, "jns"},   {TOKEN_JC, "jc"},       {TOKEN_JNC, "jnc"},
    {TOKEN_JO, "jo"},       {TOKEN_JNO, "jno"},   {TOKEN_JA, "ja"},     {TOKEN_JNA, "jna"},     {TOKEN_JL, "jl"},
    {TOKEN_JNL, "jnl"},     {TOKEN_JG, "jg"},     {TOKEN_JNG, "jng"},   {TOKEN_PUSH, "push"},   {TOKEN_POP, "pop"},
    {TOKEN_CALL, "call"},   {TOKEN_RET, "ret"},   {TOKEN_INC, "inc"},   {TOKEN_DEC, "dec"}};

Operator operators[] = {{TOKEN_COLON, ':'},  {TOKEN_COMMA, ','},  {TOKEN_LBRACKET, '['}, {TOKEN_RBRACKET, ']'},
                         {TOKEN_LPAREN, '('}, {TOKEN_RPAREN, ')'}, {TOKEN_ASSIGN, '='},   {TOKEN_ADD, '+'},
                         {TOKEN_SUB, '-'},    {TOKEN_MUL, '*'},    {TOKEN_DIV, '/'},      {TOKEN_MOD, '%'},
                         {TOKEN_AND, '&'},    {TOKEN_OR, '|'},     {TOKEN_XOR, '^'},      {TOKEN_NOT, '~'}};

bool lexer(char *path, char *text, NblSource **source, Token **_tokens, size_t *tokens_size) {
    *source = nbl_source_new(path, text);
    size_t capacity = 1024;
    size_t size = 0;
    Token *tokens = malloc(capacity * sizeof(Token));
    char *c = text;
    for (;;) {
        tokens[size].offset = c - text;
        if (size == capacity) {
            capacity *= 2;
            tokens = realloc(tokens, capacity * sizeof(Token));
        }

        // EOF
        if (*c == '\0') {
            tokens[size++].type = TOKEN_EOF;
            break;
        }

        // Comments
        if (*c == ';' || *c == '#' || (*c == '/' && *(c + 1) == '/')) {
            while (*c != '\r' && *c != '\n' && *c != '\0') {
                if (*c == '\r') c++;
                c++;
            }
            continue;
        }
        if (*c == '/' && *(c + 1) == '*') {
            c += 2;
            while (*c != '*' || *(c + 1) != '/') {
                if (*c == '\0') {
                    nbl_source_print_error(*source, c - text, "Unclosed comment block");
                    return false;
                }
                c++;
            }
            c += 2;
            continue;
        }

        // Numbers
        if (*c == '0' && *(c + 1) == 'b') {
            c += 2;
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 2);
            continue;
        }
        if (*c == '0' && (isdigit(*(c + 1)) || *(c + 1) == 'o')) {
            if (*(c + 1) == 'o') c++;
            c++;
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 8);
            continue;
        }
        if (*c == '0' && *(c + 1) == 'x') {
            c += 2;
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 16);
            continue;
        }
        if (isdigit(*c)) {
            tokens[size].type = TOKEN_NUMBER;
            tokens[size++].number = strtol(c, &c, 10);
            continue;
        }

        // Strings
        if (*c == '"' || *c == '\'') {
            char endChar = *c;
            c++;
            char *ptr = c;
            while (*c != endChar) {
                if (*c == '\0') {
                    nbl_source_print_error(*source, c - text, "Unclosed string");
                    return false;
                }
                c++;
            }
            size_t string_size = c - ptr;
            c++;

            char *string = malloc(string_size + 1);
            size_t strpos = 0;
            for (size_t i = 0; i < string_size; i++) {
                if (ptr[i] == '\\') {
                    i++;
                    if (ptr[i] == 'b')
                        string[strpos++] = '\b';
                    else if (ptr[i] == 'f')
                        string[strpos++] = '\f';
                    else if (ptr[i] == 'n')
                        string[strpos++] = '\n';
                    else if (ptr[i] == 'r')
                        string[strpos++] = '\r';
                    else if (ptr[i] == 't')
                        string[strpos++] = '\t';
                    else if (ptr[i] == 'v')
                        string[strpos++] = '\v';
                    else if (ptr[i] == '\'')
                        string[strpos++] = '\'';
                    else if (ptr[i] == '"')
                        string[strpos++] = '"';
                    else if (ptr[i] == '\\')
                        string[strpos++] = '\\';
                    else
                        string[strpos++] = ptr[i];
                } else {
                    string[strpos++] = ptr[i];
                }
            }
            string[strpos] = '\0';
            tokens[size].type = TOKEN_STRING;
            tokens[size++].string = string;
            continue;
        }

        // Keywords
        if (isalpha(*c) || *c == '_' || *c == '$') {
            char *ptr = c;
            while (isalnum(*c) || *c == '_' || *c == '$') c++;
            size_t string_size = c - ptr;

            bool found = false;
            for (size_t i = 0, j = sizeof(keywords) / sizeof(Keyword) - 1; i < sizeof(keywords) / sizeof(Keyword);
                 i++, j--) {
                Keyword *keyword = &keywords[j];
                size_t keyword_size = strlen(keyword->keyword);
                if (!memcmp(ptr, keyword->keyword, keyword_size) && string_size == keyword_size) {
                    tokens[size++].type = keyword->type;
                    found = true;
                    break;
                }
            }
            if (!found) {
                tokens[size].type = TOKEN_VARIABLE;
                tokens[size++].string = strndup(ptr, string_size);
            }
            continue;
        }

        // Operators
        if (*c == '<' && *(c + 1) == '<') {
            c += 2;
            tokens[size++].type = TOKEN_SHL;
            continue;
        }
        if (*c == '>' && *(c + 1) == '>') {
            c += 2;
            tokens[size++].type = TOKEN_SHR;
            continue;
        }
        bool found_operator = false;
        for (size_t i = 0; i < sizeof(operators) / sizeof(Operator); i++) {
            Operator *operator = &operators[i];
            if (*c == operator->operator) {
                c++;
                tokens[size++].type = operator->type;
                found_operator = true;
                break;
            }
        }
        if (found_operator) {
            continue;
        }

        // Whitespace
        if (*c == ' ' || *c == '\t') {
            c++;
            continue;
        }
        if (*c == '\n' || *c == '\r') {
            if (*c == '\r') c++;
            c++;
            continue;
        }

        nbl_source_print_error(*source, c - text, "Unknown character: %c", *c);
        return false;
    }
    *_tokens = tokens;
    *tokens_size = size;
    return true;
}
