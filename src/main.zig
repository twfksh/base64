const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        return Base64{
            ._table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        };
    }

    fn _char_at(self: Base64, index: u8) u8 {
        return self._table[index];
    }

    fn _char_index(self: Base64, char: u8) u8 {
        if (char == '=') return 64;

        var index: u8 = 0;
        for (0..63) |_| {
            if (self._char_at(index) == char) break;
            index += 1;
        }
        return index;
    }

    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const n_output = try _calc_encode_length(input);
        var output = try allocator.alloc(u8, n_output);
        var buf = [3]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (input, 0..) |_, i| {
            buf[count] = input[i];
            count += 1;
            if (count == 3) {
                output[iout] = self._char_at(buf[0] >> 2);
                output[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                output[iout + 2] = self._char_at(((buf[1] & 0x0f) << 2) + (buf[2] >> 6));
                output[iout + 3] = self._char_at(buf[2] & 0x3f);
                iout += 4;
                count = 0;
            }
        }

        if (count == 1) {
            output[iout] = self._char_at(buf[0] >> 2);
            output[iout + 1] = self._char_at((buf[0] & 0x03) << 4);
            output[iout + 2] = '=';
            output[iout + 3] = '=';
        }

        if (count == 2) {
            output[iout] = self._char_at(buf[0] >> 2);
            output[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            output[iout + 2] = self._char_at((buf[1] & 0x0f) << 2);
            output[iout + 3] = '=';
            iout += 4;
        }

        return output;
    }

    pub fn decode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const n_output = try _calc_decode_length(input);
        var output = try allocator.alloc(u8, n_output);
        var buf = [4]u8{ 0, 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (0..input.len) |i| {
            buf[count] = self._char_index(input[i]);
            count += 1;
            if (count == 4) {
                output[iout] = (buf[0] << 2) + (buf[1] >> 4);
                if (buf[2] != 64) output[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
                if (buf[3] != 64) output[iout + 2] = (buf[2] << 6) + buf[3];
                iout += 3;
                count = 0;
            }
        }

        return output;
    }
};

fn _calc_encode_length(input: []const u8) !usize {
    if (input.len < 3) {
        const n_output: usize = 4;
        return n_output;
    }
    const n_output: usize = try std.math.divCeil(usize, input.len, 3);
    return n_output * 4;
}

fn _calc_decode_length(input: []const u8) !usize {
    if (input.len < 4) {
        const n_output: usize = 3;
        return n_output;
    }
    const n_output: usize = try std.math.divFloor(usize, input.len, 4);
    return n_output * 4;
}

pub fn main() !void {
    var memory_buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory_buf);
    const allocator = fba.allocator();

    try stdout.print("Input: ", .{});
    const input = try stdin.readUntilDelimiterAlloc(allocator, '\n', 100);

    const base64 = Base64.init();

    const encoded_text = try base64.encode(allocator, input[0..]);
    try stdout.print("Encoded: '{s}'\n", .{encoded_text});
    const decoded_text = try base64.decode(allocator, encoded_text);
    try stdout.print("Decoded: '{s}'\n", .{decoded_text});
}
