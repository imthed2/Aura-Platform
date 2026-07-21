import Foundation

enum CompanionFrameType: UInt8, Sendable {
    case pairSetupStart = 0x03
    case pairSetupNext = 0x04
    case pairVerifyStart = 0x05
    case pairVerifyNext = 0x06
    case encryptedOPACK = 0x08
}

struct CompanionFrame: Equatable, Sendable {
    static let headerLength = 4
    static let maximumPayloadLength = 1_048_576

    let type: CompanionFrameType
    let payload: Data
}

enum CompanionFrameCodecError: Error, Equatable, Sendable {
    case incompleteHeader
    case unsupportedFrameType
    case payloadTooLarge
    case invalidPayloadLength
}

enum CompanionFrameCodec {
    static func encode(_ frame: CompanionFrame) throws -> Data {
        guard frame.payload.count <= CompanionFrame.maximumPayloadLength else {
            throw CompanionFrameCodecError.payloadTooLarge
        }

        let length = frame.payload.count
        return Data([
            frame.type.rawValue,
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF)
        ]) + frame.payload
    }

    static func payloadLength(from header: Data) throws -> Int {
        guard header.count == CompanionFrame.headerLength else {
            throw CompanionFrameCodecError.incompleteHeader
        }

        let bytes = Array(header)
        let length = (Int(bytes[1]) << 16) | (Int(bytes[2]) << 8) | Int(bytes[3])
        guard length <= CompanionFrame.maximumPayloadLength else {
            throw CompanionFrameCodecError.payloadTooLarge
        }
        return length
    }

    static func decode(header: Data, payload: Data) throws -> CompanionFrame {
        guard header.count == CompanionFrame.headerLength else {
            throw CompanionFrameCodecError.incompleteHeader
        }
        guard let type = CompanionFrameType(rawValue: header[header.startIndex]) else {
            throw CompanionFrameCodecError.unsupportedFrameType
        }
        guard try payloadLength(from: header) == payload.count else {
            throw CompanionFrameCodecError.invalidPayloadLength
        }
        return CompanionFrame(type: type, payload: payload)
    }
}

enum HAPTLVTag: UInt8, Sendable {
    case method = 0x00
    case identifier = 0x01
    case salt = 0x02
    case publicKey = 0x03
    case proof = 0x04
    case encryptedData = 0x05
    case sequence = 0x06
    case error = 0x07
    case backOff = 0x08
    case certificate = 0x09
    case signature = 0x0A
    case permissions = 0x0B
    case fragmentData = 0x0C
    case fragmentLast = 0x0D
    case name = 0x11
    case flags = 0x13
}

struct HAPTLVEntry: Equatable, Sendable {
    let tag: HAPTLVTag
    let value: Data
}

enum HAPTLV8Error: Error, Equatable, Sendable {
    case malformed
    case valueTooLarge
}

enum HAPTLV8 {
    static let maximumValueLength = 16_384

    static func encode(_ entries: [HAPTLVEntry]) throws -> Data {
        var encoded = Data()

        for entry in entries {
            let value = Data(entry.value)
            guard value.count <= maximumValueLength else {
                throw HAPTLV8Error.valueTooLarge
            }

            if value.isEmpty {
                encoded.append(contentsOf: [entry.tag.rawValue, 0])
                continue
            }

            var offset = 0
            while offset < value.count {
                let length = min(255, value.count - offset)
                encoded.append(entry.tag.rawValue)
                encoded.append(UInt8(length))
                encoded.append(value[offset..<(offset + length)])
                offset += length
            }
        }

        return encoded
    }

    static func decode(_ data: Data) throws -> [HAPTLVTag: Data] {
        let bytes = Array(data)
        var decoded: [HAPTLVTag: Data] = [:]
        var offset = 0

        while offset < bytes.count {
            guard offset + 2 <= bytes.count else { throw HAPTLV8Error.malformed }
            let tagByte = bytes[offset]
            let length = Int(bytes[offset + 1])
            offset += 2

            guard offset + length <= bytes.count else {
                throw HAPTLV8Error.malformed
            }

            guard let tag = HAPTLVTag(rawValue: tagByte) else {
                offset += length
                continue
            }

            var value = decoded[tag, default: Data()]
            guard value.count + length <= maximumValueLength else {
                throw HAPTLV8Error.valueTooLarge
            }
            value.append(contentsOf: bytes[offset..<(offset + length)])
            decoded[tag] = value
            offset += length
        }

        return decoded
    }
}

indirect enum OPACKValue: Equatable, Sendable {
    case null
    case boolean(Bool)
    case integer(UInt64)
    case string(String)
    case data(Data)
    case dictionary([String: OPACKValue])
}

enum OPACKCodecError: Error, Equatable, Sendable {
    case unsupportedValue
    case malformed
    case limitExceeded
    case trailingData
}

enum OPACKCodec {
    static let maximumPayloadLength = 1_048_576
    private static let maximumDepth = 8
    private static let maximumContainerCount = 64

    static func encode(_ value: OPACKValue) throws -> Data {
        let data = try encodeValue(value, depth: 0)
        guard data.count <= maximumPayloadLength else { throw OPACKCodecError.limitExceeded }
        return data
    }

    static func decode(_ data: Data) throws -> OPACKValue {
        guard !data.isEmpty, data.count <= maximumPayloadLength else {
            throw OPACKCodecError.limitExceeded
        }

        var parser = OPACKParser(data: Data(data))
        let value = try parser.parse(depth: 0)
        guard parser.isAtEnd else { throw OPACKCodecError.trailingData }
        return value
    }

    private static func encodeValue(_ value: OPACKValue, depth: Int) throws -> Data {
        guard depth <= maximumDepth else { throw OPACKCodecError.limitExceeded }

        switch value {
        case .null:
            return Data([0x04])
        case .boolean(let value):
            return Data([value ? 0x01 : 0x02])
        case .integer(let value):
            if value < 0x28 {
                return Data([UInt8(value) + 0x08])
            }
            if value <= UInt8.max {
                return Data([0x30, UInt8(value)])
            }
            if value <= UInt16.max {
                return Data([0x31]) + littleEndianBytes(value, count: 2)
            }
            if value <= UInt32.max {
                return Data([0x32]) + littleEndianBytes(value, count: 4)
            }
            return Data([0x33]) + littleEndianBytes(value, count: 8)
        case .string(let string):
            let bytes = Data(string.utf8)
            if bytes.count <= 0x20 {
                return Data([0x40 + UInt8(bytes.count)]) + bytes
            }
            return try lengthPrefixed(bytes, shortMarker: 0x61, longMarker: 0x64)
        case .data(let data):
            if data.count <= 0x20 {
                return Data([0x70 + UInt8(data.count)]) + data
            }
            return try lengthPrefixed(data, shortMarker: 0x91, longMarker: 0x93)
        case .dictionary(let dictionary):
            guard dictionary.count < 15, dictionary.count <= maximumContainerCount else {
                throw OPACKCodecError.limitExceeded
            }

            var encoded = Data([0xE0 + UInt8(dictionary.count)])
            for key in dictionary.keys.sorted() {
                encoded += try encodeValue(.string(key), depth: depth + 1)
                guard let child = dictionary[key] else { throw OPACKCodecError.malformed }
                encoded += try encodeValue(child, depth: depth + 1)
            }
            return encoded
        }
    }

    private static func lengthPrefixed(
        _ data: Data,
        shortMarker: UInt8,
        longMarker: UInt8
    ) throws -> Data {
        if data.count <= UInt8.max {
            return Data([shortMarker, UInt8(data.count)]) + data
        }
        guard data.count <= Int(UInt32.max) else { throw OPACKCodecError.limitExceeded }
        return Data([longMarker]) + littleEndianBytes(UInt64(data.count), count: 4) + data
    }

    private static func littleEndianBytes(_ value: UInt64, count: Int) -> Data {
        Data((0..<count).map { UInt8((value >> ($0 * 8)) & 0xFF) })
    }
}

private struct OPACKParser {
    let data: Data
    var offset = 0
    var objectTable: [OPACKValue] = []

    var isAtEnd: Bool { offset == data.count }

    mutating func parse(depth: Int) throws -> OPACKValue {
        guard depth <= 8, offset < data.count else { throw OPACKCodecError.malformed }
        let marker = try readByte()

        switch marker {
        case 0x01:
            return .boolean(true)
        case 0x02:
            return .boolean(false)
        case 0x04:
            return .null
        case 0x08...0x2F:
            return .integer(UInt64(marker - 0x08))
        case 0x30...0x33:
            let byteCount = 1 << Int(marker - 0x30)
            return .integer(try readLittleEndianInteger(byteCount: byteCount))
        case 0x40...0x60:
            return try parseString(length: Int(marker - 0x40))
        case 0x61...0x64:
            return try parseString(length: Int(try readLittleEndianInteger(byteCount: Int(marker - 0x60))))
        case 0x70...0x90:
            return try parseData(length: Int(marker - 0x70))
        case 0x91...0x94:
            let lengthByteCount = 1 << Int(marker - 0x91)
            return try parseData(length: Int(try readLittleEndianInteger(byteCount: lengthByteCount)))
        case 0xA0...0xC0:
            let index = Int(marker - 0xA0)
            guard objectTable.indices.contains(index) else { throw OPACKCodecError.malformed }
            return objectTable[index]
        case 0xC1...0xC4:
            let index = Int(try readLittleEndianInteger(byteCount: Int(marker - 0xC0)))
            guard objectTable.indices.contains(index) else { throw OPACKCodecError.malformed }
            return objectTable[index]
        case 0xE0...0xEE:
            let count = Int(marker - 0xE0)
            guard count <= 64 else { throw OPACKCodecError.limitExceeded }
            var dictionary: [String: OPACKValue] = [:]
            for _ in 0..<count {
                guard case .string(let key) = try parse(depth: depth + 1) else {
                    throw OPACKCodecError.malformed
                }
                dictionary[key] = try parse(depth: depth + 1)
            }
            return .dictionary(dictionary)
        default:
            throw OPACKCodecError.unsupportedValue
        }
    }

    private mutating func parseString(length: Int) throws -> OPACKValue {
        let bytes = try readData(count: length)
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw OPACKCodecError.malformed
        }
        let value = OPACKValue.string(string)
        appendObject(value)
        return value
    }

    private mutating func parseData(length: Int) throws -> OPACKValue {
        let value = OPACKValue.data(Data(try readData(count: length)))
        appendObject(value)
        return value
    }

    private mutating func appendObject(_ value: OPACKValue) {
        if !objectTable.contains(value) {
            objectTable.append(value)
        }
    }

    private mutating func readLittleEndianInteger(byteCount: Int) throws -> UInt64 {
        guard (1...8).contains(byteCount) else { throw OPACKCodecError.malformed }
        let bytes = try readData(count: byteCount)
        return bytes.enumerated().reduce(0) { partial, item in
            partial | (UInt64(item.element) << (item.offset * 8))
        }
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw OPACKCodecError.malformed }
        defer { offset += 1 }
        return data[offset]
    }

    private mutating func readData(count: Int) throws -> Data {
        guard count >= 0, count <= OPACKCodec.maximumPayloadLength,
              offset + count <= data.count else {
            throw OPACKCodecError.malformed
        }
        defer { offset += count }
        return data[offset..<(offset + count)]
    }
}
