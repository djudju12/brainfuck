package main

import "core:fmt"
import "core:os"

Lexer :: struct {
    text: []byte,
    cursor: uint
}

new_lexer :: proc(text_to_lex: []byte) -> Lexer {
    return Lexer{ text_to_lex, 0 }
}

Token_Kind :: enum u8 {
    INC_PTR  = '>',
    DEC_PTR  = '<',
    INC_DATA = '+',
    DEC_DATA = '-',
    OP_BCKT  = '[',
    CL_BCKT  = ']',
    GET_CHR  = ',',
    PUT_CHR  = '.',
}

Token :: struct {
    kind: Token_Kind,
    value: int
}

is_valid_token :: proc(c: byte) -> bool {
    for s in Token_Kind {
        if u8(s) == c {
            return true
        }
    }

    return false
}

next_char :: proc(lex: ^Lexer) -> (u8, bool) {
    if lex.cursor >= len(lex.text) {
        return 0, true
    }

    c := lex.text[lex.cursor]
    lex.cursor += 1;
    return c, false
}

next_token :: proc(lex: ^Lexer) -> (Token, bool) {
    c, eof := next_char(lex)
    for !eof {
        if is_valid_token(c) {
            return Token{ Token_Kind(c), 0 }, false
        }

        c, eof = next_char(lex)
    }

    return Token{}, true
}

DATA_ARRAY_LEN :: 30000
Brain_Fuck :: struct {
    data_ptr: int,
    data: [DATA_ARRAY_LEN]byte,
    instructions: [dynamic]Token,
    ip: int
}

Error :: enum {
    None,
    Unbalanced_Brackets
}

new_brainfuck :: proc(code: []byte) -> (Brain_Fuck, Error) {
    bf : Brain_Fuck = Brain_Fuck{ data_ptr = 0, ip = 0 }

    lexer := new_lexer(code)
    token, eof := next_token(&lexer)
    for !eof {
        append(&bf.instructions, token)
        token, eof = next_token(&lexer)
    }

    for &t, ip in bf.instructions {
        if t.kind == .OP_BCKT {
            ip_cl := ip
            op_bckt_cnt := 1
            for &t2, cnt in bf.instructions[ip + 1:] {
                ip2 := cnt + ip + 1
                if t2.kind == .OP_BCKT {
                    op_bckt_cnt += 1
                } else if t2.kind == .CL_BCKT {
                    if op_bckt_cnt > 1 {
                        op_bckt_cnt -= 1
                    } else {
                        t2.value = ip
                        ip_cl = ip2
                        break
                    }
                }
            }

            if ip_cl == ip {
                return bf, .Unbalanced_Brackets
            }

            t.value = ip_cl
        }
    }

    return bf, .None
}

getch :: proc () -> byte {
    buf: [1]byte;
    r, err := os.read(os.stdin, buf[:])
    assert(err == 0)
    assert(r == 1)
    return buf[0]
}

// https://en.wikipedia.org/wiki/Brainfuck
run :: proc(bf: ^Brain_Fuck) {
    for bf.ip < len(bf.instructions) {
        assert(bf.data_ptr < DATA_ARRAY_LEN)
        assert(bf.data_ptr >= 0)

        instruction := bf.instructions[bf.ip]
        #partial switch instruction.kind {
            // Output the byte at the data pointer.
            case .PUT_CHR:
                fmt.print(rune(bf.data[bf.data_ptr]))

            // Accept one byte of input, storing its value in the byte at the data pointer.
            case .GET_CHR:
                bf.data[bf.data_ptr] = getch()


            // Increment the data pointer by one (to point to the next cell to the right)
            case .INC_PTR:
                bf.data_ptr += 1

            // Decrement the data pointer by one (to point to the next cell to the left)
            case .DEC_PTR:
                bf.data_ptr -= 1

            // Increment the byte at the data pointer by one
            case .INC_DATA:
                bf.data[bf.data_ptr] += 1

            // Decrement the byte at the data pointer by one
            case .DEC_DATA:
                bf.data[bf.data_ptr] -= 1

            // If the byte at the data pointer is zero, then instead of moving the instruction pointer forward to the
            // next command, jump it forward to the command after the matching ] command
            case .OP_BCKT:
                if bf.data[bf.data_ptr] == 0 {
                    bf.ip = instruction.value + 1
                    continue
                }

            // If the byte at the data pointer is nonzero, then instead of moving the instruction pointer forward to the
            // next command, jump it back to the command after the matching [ command
            case .CL_BCKT:
                if bf.data[bf.data_ptr] != 0 {
                    bf.ip = instruction.value + 1
                    continue
                }
        }

        bf.ip += 1
    }
}

main :: proc() {
    program_name := os.args[0]
    if len(os.args) < 2 {
        fmt.printf("usage: %s [file]\n", program_name)
        return
    }

    file_path := os.args[1]
    data, ok := os.read_entire_file(file_path, context.allocator);
    if !ok {
        return
    }

    defer delete(data, context.allocator)
    bf, err := new_brainfuck(data)
    if err != nil {
        fmt.println(err)
        return
    }

    run(&bf)
}