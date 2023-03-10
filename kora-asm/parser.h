#pragma once

#include "lexer.h"

// Node
typedef enum NodeType {
    NODE_NUMBER,

    NODE_ADD,
} NodeType;

typedef struct Node Node;
struct Node {
    NodeType type;
    int32_t offset;
    Source *source;
    union {
        int32_t number;
        char *string;
        Node *unary;
        struct {
            Node *lhs;
            Node *rhs;
        };
        struct {
            TokenType statement;
            void *nodes;
        };
    };
};
