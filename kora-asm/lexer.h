#pragma once

#include <stdint.h>
#include <stdbool.h>

// Source
typedef struct Source {
    int32_t refs;
    char *path;
    char *dirname;
    char *basename;
    char *text;
} Source;

Source *source_new(char *path, char *text);

Source *source_ref(Source *source);

void source_get_line_column(Source *source, int32_t offset, int32_t *line, int32_t *column, char **line_start);

void source_print_error(Source *source, int32_t offset, char *format, ...);

void source_release(Source *source);

// Token
typedef enum TokenType {
    TOKEN_EOF,
    TOKEN_NUMBER,
    TOKEN_VARIABLE,
    TOKEN_STRING,

    // Operators
    TOKEN_COLON,
    TOKEN_COMMA,
    TOKEN_LBRACKET,
    TOKEN_RBRACKET,
    TOKEN_LPAREN,
    TOKEN_RPAREN,
    TOKEN_ASSIGN,
    TOKEN_ADD,
    TOKEN_SUB,
    TOKEN_MUL,
    TOKEN_DIV,
    TOKEN_MOD,
    TOKEN_AND,
    TOKEN_OR,
    TOKEN_XOR,
    TOKEN_NOT,
    TOKEN_SHL,
    TOKEN_SHR,

    // Keywords
    TOKEN_DB,
    TOKEN_DH,
    TOKEN_DW,
    TOKEN_TIMES,
    TOKEN_ALIGN,
    TOKEN_BYTE,
    TOKEN_HALF,
    TOKEN_WORD,

    // Registers
    TOKEN_T0,
    TOKEN_T1,
    TOKEN_T2,
    TOKEN_T3,
    TOKEN_S0,
    TOKEN_S1,
    TOKEN_S2,
    TOKEN_S3,
    TOKEN_A0,
    TOKEN_A1,
    TOKEN_A2,
    TOKEN_A3,
    TOKEN_BP,
    TOKEN_SP,
    TOKEN_RP,
    TOKEN_FLAGS,

    // Opcodes
    TOKEN_MOV,
    TOKEN_MOVSX,
    TOKEN_LW,
    TOKEN_LH,
    TOKEN_LHSX,
    TOKEN_LB,
    TOKEN_LBSX,
    TOKEN_SW,
    TOKEN_SH,
    TOKEN_SB,
    TOKEN_ADD,
    TOKEN_ADC,
    TOKEN_SUB,
    TOKEN_SBB,
    TOKEN_NEG,
    TOKEN_CMP,
    TOKEN_AND,
    TOKEN_OR,
    TOKEN_XOR,
    TOKEN_NOT,
    TOKEN_TEST,
    TOKEN_SHL,
    TOKEN_SHR,
    TOKEN_SAR,
    TOKEN_JMP,
    TOKEN_CALL,
    TOKEN_JC,
    TOKEN_JNC,
    TOKEN_JZ,
    TOKEN_JNZ,
    TOKEN_JS,
    TOKEN_JNS,
    TOKEN_JO,
    TOKEN_JNO,
    TOKEN_JA,
    TOKEN_JNA,
    TOKEN_JL,
    TOKEN_JNL,
    TOKEN_JG,
    TOKEN_JNG,

    // Psuedo opcodes
    TOKEN_INC,
    TOKEN_DEC,
    TOKEN_HLT,
    TOKEN_RET
} TokenType;

typedef struct Token {
    TokenType type;
    int32_t offset;
    union {
        int32_t number;
        char *string;
    };
} Token;

char *token_type_to_string(TokenType type);

void token_free(Token *token);

// Lexer
typedef struct Keyword {
    TokenType type;
    char *keyword;
} Keyword;

typedef struct Operator {
    TokenType type;
    char operator;
} Operator;

bool lexer(char *path, char *text, Source **source, Token **tokens, size_t *tokens_size);
