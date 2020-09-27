#include "token.h"
#include "utils.h"
#include <stdlib.h>

Token *token_new(TokenType type) {
    Token *token = malloc(sizeof(Token));
    token->type = type;
    return token;
}

char *token_to_string(Token *token) {
    if (token->type == TOKEN_TYPE_KEYWORD) {
        return string_copy(token->value.string);
    }

    if (token->type == TOKEN_TYPE_NUMBER) {
        return string_format("%d", token->value.number);
    }

    return NULL;
}

void token_free(Token *token) {
    if (token->type == TOKEN_TYPE_KEYWORD) {
        free(token->value.string);
    }

    free(token);
}
