#include <stdio.h>
#include <stdlib.h>
#include "utils.h"
#include "lexer.h"
#include "token.h"

int main(int argc, char **argv) {
    if (argc == 1) {
        printf("Kora Assembler v0.1.0\n");
        return EXIT_SUCCESS;
    }

    char *text = file_read(argv[1]);

    List *tokens = lexer(text);

    printf("# Tokens:\n");

    for (int i = 0; i < tokens->size; i++) {
        char *token_string = token_to_string(tokens->items[i]);
        printf("%s", token_string);
        free(token_string);

        if (i != tokens->size - 1) {
            printf(", ");
        }
    }

    list_free(tokens, token_free);

    free(text);
}
