#ifndef TOKEN_H
#define TOKEN_H

#include <stdint.h>

typedef enum TokenType {
    TOKEN_TYPE_KEYWORD,
    TOKEN_TYPE_NUMBER
} TokenType;

typedef struct Token {
    TokenType type;
    union {
        int number;
        char *string;
    } value;
} Token;

Token *token_new(TokenType type);

char *token_to_string(Token *token);

void token_free(Token *token);

#endif
