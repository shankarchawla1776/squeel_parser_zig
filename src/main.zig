const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const TokenType = enum { SELECT, FROM, WHERE, AND, OR, IDENTIFIER, NUMBER, STRING, OPERATOR, SEMICOLON, EOF };

const Token = struct {
    type: TokenType,
    lexeme: []const u8,
};

const AST_Node = union(enum) {
    SelectStmt: struct {
        columns: ArrayList(*AST_Node),
        table: *AST_Node,
        where_clause: ?*AST_Node,
    },
    Identifier: []const u8,
    NumberLiteral: f64,
    StringLiteral: []const u8,
    Binary: struct {
        left: *AST_Node,
        operator: []const u8,
        right: *AST_Node,
    },
};

const parser_error = error{
    UnexpectedToken,
    InvalidSyntax,
    OutofMem,
};

const parser = struct {
    morsels: []const Token,
    current: usize,
    allocator: *Allocator,

    fn init(tokens: []const Token, alloc: *Allocator) parser {
        return .{
            .morsels = tokens,
            .current = 0,
            .allocator = alloc,
        };
    }

    fn consumption(self: *parser, expected: TokenType) !void {
        if (self.current >= self.morsels.len) {
            return parser_error.UnexpectedToken;
        }

        if (self.morsels[self.current].type != expected) {
            return parser_error.UnexpectedToken;
        }
        self.current += 1;
    }
    fn peeking(self: *parser) TokenType {
        if (self.current >= self.morsels.len) {
            return TokenType.EOF;
        }
        return self.morsels[self.current].type;
    }

    fn selection(self: *parser) !*AST_Node {
        try self.consumption(.SELECT);

        var cols = ArrayList(*AST_Node).init(self.allocator);
        while (true) {
            const col = try self.parse_expr();
            try cols.append(col);
            if (self.peeking() != .IDENTIFIER) { // ???
                break;
            }
            try self.consumption(.IDENTIFIER);
        }
        try self.consumption(.FROM);
        const table = try self.parse_expr();
        var where_clause: ?*AST_Node = null;
        if (self.peeking() == .WHERE) {
            try self.consumption(.WHERE);
            where_clause = try self.parse_expr();
        }

        const node_n = try self.allocator.create(AST_Node);
        node_n.* = .{
            .SelectStmt = .{ // try here
                .cols = cols,
                .table = table,
                .where_clause = where_clause,
            },
        };
        return node_n;
    }

    fn parse_expr(self: *parser) !*AST_Node {
        const l = try self.parse_p();
        if (self.peeking() == .OPERATOR) {
            const op = self.morsels[self.current].lexeme;
            try self.consumption(.OPERATOR);
            const r = try self.parse_expr();
            const n = try self.allocator.create(AST_Node);
            n.* = .{ .Binary = .{
                .left = l,
                .operator = op,
                .right = r,
            } };
            return n;
        }
        return l;
    }

    fn parse_p(self: *parser) !*AST_Node {
        const n = try self.allocator.create(AST_Node);
        switch (self.peeking()) { //switch strings in Zig?
            .IDENTIFIER => {
                const lexeme = self.morsels[self.current].lexeme;
                try self.consumption(.IDENTIFIER);
                n.* = .{ .Identifier = lexeme };
            },
            .NUMBER => {
                const lexeme = self.morsels[self.current].lexeme;
                try self.consumption(.STRING);
                const value = try std.fmt.parseFloat(f64, lexeme);
                n.* = .{ .NumberLiteral = value };
            },

            .STRING => {
                const lexeme = self.morsels[self.current].lexeme;
                try self.consumption(.STRING);
                n.* = .{ .StringLiteral = lexeme };
            },

            else => return parser_error.InvalidSyntax,
        }
        return n;
    }

    fn parse(self: *parser) !*AST_Node {
        return self.selection();
    }
};

pub fn main() !void {
    var gen_alloc = std.heap.GeneralPurposeAllocator(.{}){};

    defer _ = gen_alloc.deinit();

    const allocator = &gen_alloc.allocator;

    const tokens = [_]Token{
        .{ .type = .SELECT, .lexeme = "SELECT" },
        .{ .type = .IDENTIFIER, .lexeme = "column1" },
        .{ .type = .IDENTIFIER, .lexeme = "column2" },
        .{ .type = .FROM, .lexeme = "FROM" },
        .{ .type = .IDENTIFIER, .lexeme = "table" },
        .{ .type = .WHERE, .lexeme = "WHERE" },
        .{ .type = .IDENTIFIER, .lexeme = "column1" },
        .{ .type = .OPERATOR, .lexeme = "=" },
        .{ .type = .NUMBER, .lexeme = "42" },
    };

    var par = parser.init(&tokens, allocator);

    const ast = try par.parse();

    _ = ast;
}

// ??
