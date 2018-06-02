import BigInt
@_exported import struct BigInt.BigInt  // re-export BigInt

///
/// Placeholder for utility functions and values
///
public class BigNum {
    public static let int2char = "0123456789abcdefghijklmnopqrstuvwxyz".map{$0}
    public static let char2int:[Character:Int] = {
        var result = [Character:Int]()
        for i in 0..<int2char.count {
            result[int2char[i]] = i
        }
        return result
    }()
}
