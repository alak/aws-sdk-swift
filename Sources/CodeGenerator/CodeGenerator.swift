//
//  CodeGenerator.swift
//  AWSSDKSwift
//
//  Created by Yuki Takei on 2017/04/04.
//
//

// TODO should use template engine to generate code

import Foundation
import SwiftyJSON
import AWSSDKSwiftCore

extension Location {
    func enumStyleDescription() -> String {
        switch self {
        case .uri(locationName: let name):
            return ".uri(locationName: \"\(name)\")"
        case .querystring(locationName: let name):
            return ".querystring(locationName: \"\(name)\")"
        case .header(locationName: let name):
            return ".header(locationName: \"\(name)\")"
        case .body(locationName: let name):
            return ".body(locationName: \"\(name)\")"
        }
    }

    init?(json: JSON) {
        guard let name = json["locationName"].string else {
            return nil
        }

        let loc = json["location"].string ?? "body"

        switch loc.lowercased() {
        case "uri":
            self = .uri(locationName: name)

        case "querystring":
            self = .querystring(locationName: name)

        case "header":
            self = .header(locationName: name)

        case  "body":
            self = .body(locationName: name)

        default:
            return nil
        }
    }
}

extension ShapeEncoding {
    func enumStyleDescription() -> String {
        switch self {
        case .default:
            return ".default"
        case .list(let member):
            return ".list(member:\"\(member)\")"
        case .flatList:
            return ".flatList"
        case .map(let entry, let key, let value):
            return ".map(entry:\"\(entry)\", key: \"\(key)\", value: \"\(value)\")"
        case .flatMap(let key, let value):
            return ".flatMap(key: \"\(key)\", value: \"\(value)\")"
        }
    }
    
    init?(json: JSON) {
        if json["type"].string == "list" {
            if json["flattened"].bool == true {
                self = .flatList
            } else {
                self = .list(member: json["member"]["locationName"].string ?? "member")
            }
        } else if json["type"].string == "map" {
            let key = json["key"]["locationName"].string ?? "key"
            let value = json["value"]["locationName"].string ?? "value"
            if json["flattened"].bool == true {
                self = .flatMap(key: key, value: value)
            } else {
                let entry = "entry"
                self = .map(entry: entry, key: key, value: value)
            }
        } else {
            return nil
        }
    }
}

extension ServiceProtocol {
    public func instantiationCode() -> String {
        if let version = self.version {
            return "ServiceProtocol(type: .\(type), version: ServiceProtocol.Version(major: \(version.major), minor: \(version.minor)))"
        } else {
            return "ServiceProtocol(type: .\(type))"
        }
    }
}

extension Operation {
    func generateSwiftFunctionCode() -> String {
        var code = ""

        if let _ = self.outputShape { }
        else {
            code += "@discardableResult "
        }

        if let shape = self.inputShape {
            code += "public func \(name.toSwiftVariableCase())(_ input: \(shape.swiftTypeName))"
        } else {
            code += "public func \(name.toSwiftVariableCase())()"
        }

        code += " throws"

        if let shape = self.outputShape {
            code += " -> Future<\(shape.swiftTypeName)>"
        } else {
            code += " -> Future<Void>"
        }

        code += " {\n"

        code += "\(indt(1))return try client.send("

        code += "operation: \"\(name)\", "
        code += "path: \"\(path)\", "
        code += "httpMethod: \"\(httpMethod)\""
        if inputShape != nil {
            code += ", "
            code += "input: input"
        }

        code += ")\n"
        code += "}"

        return code
    }
}

extension Member {
    var variableName: String {
        return name.toSwiftVariableCase()
    }

    var defaultValue: String {
        if !required {
            return "nil"
        }

        switch shape.type {
        case .integer(_), .float(_), .double(_), .long(_):
            return "0"
        case .boolean:
            return "false"
        case .blob(_):
            return "Data()"
        case .timestamp:
            return "Date()"
        case .list(_):
            return "[]"
        case .map(_):
            return "[:]"
        case .structure(_):
            return "\(shape.name)()"
        default:
            return "\"\""
        }
    }

    func toSwiftMutableMemberSyntax() -> String {
        let optionalSuffix = required ? "" : "?"
        return "var \(name.toSwiftVariableCase()): \(swiftTypeName)\(optionalSuffix) = \(defaultValue)"
    }

    func toSwiftImmutableMemberSyntax() -> String {
        let optionalSuffix = required ? "" : "?"
        return "let \(name.toSwiftVariableCase()): \(swiftTypeName)\(optionalSuffix)"
    }

    func toSwiftArgumentSyntax() -> String {
        let optionalSuffix = required ? "" : "?"
        let defaultArgument = required ? "" : " = nil"
        return "\(name.toSwiftLabelCase()): \(swiftTypeName)\(optionalSuffix)\(defaultArgument)"
    }
}

extension AWSShapeMember.Shape {
    public var enumStyleDescription: String {
        return ".\(self)"
    }
}

extension AWSService {
    func generateErrorCode() -> String {
        if errorShapeNames.isEmpty { return "" }
        var code = ""
        code += autoGeneratedHeader
        code += "import AWSSDKSwiftCore"
        code += "\n\n"
        code += "/// Error enum for \(serviceName)\n"
        code += ""
        code += "public enum \(serviceErrorName): AWSErrorType {\n"
        for name in errorShapeNames {
            code += "\(indt(1))case \(name.toSwiftVariableCase())(message: String?)\n"
        }
        code += "}"
        code += "\n\n"
        code += "extension \(serviceErrorName) {\n"
        code += "\(indt(1))public init?(errorCode: String, message: String?){\n"
        code += "\(indt(2))var errorCode = errorCode\n"
        code += "\(indt(2))if let index = errorCode.index(of: \"#\") {\n"
            code += "\(indt(3))errorCode = String(errorCode[errorCode.index(index, offsetBy: 1)...])\n"
        code += "\(indt(2))}\n"

        code += "\(indt(2))switch errorCode {\n"
        for name in errorShapeNames {
            code += "\(indt(2))case \"\(name)\":\n"
            code += "\(indt(3))self = .\(name.toSwiftVariableCase())(message: message)\n"
        }
        code += "\(indt(2))default:\n"
        code += "\(indt(3))return nil\n"
        code += "\(indt(2))}\n"
        code += "\(indt(1))}\n"
        code += "}"

        return code
    }

    func generateServiceCode() -> String {
        var code = ""
        code += autoGeneratedHeader
        code += "import Foundation\n"
        code += "import AWSSDKSwiftCore\n"
        code += "import NIO\n\n"

        switch endpointPrefix {
        case "s3":
            code += "import S3Middleware\n\n"
        case "glacier":
            code += "import GlacierMiddleware\n\n"
        default:
            break
        }

        code += "/**\n"
        code += serviceDescription+"\n"
        code += "*/\n"
        code += "public "
        code += "struct \(serviceName) {\n\n"
        code += "\(indt(1))let client: AWSClient\n\n"

        var middlewares = "[]"
        switch endpointPrefix {
        case "s3":
            middlewares = "[S3RequestMiddleware()]"
        case "glacier":
            middlewares = "[GlacierRequestMiddleware(apiVersion: \"\(version)\")]"
        default:
            break
        }

        code += "\(indt(1))public init(accessKeyId: String? = nil, secretAccessKey: String? = nil, region: AWSSDKSwiftCore.Region? = nil, endpoint: String? = nil) {\n"
        code += "\(indt(2))self.client = AWSClient(\n"
        code += "\(indt(3))accessKeyId: accessKeyId,\n"
        code += "\(indt(3))secretAccessKey: secretAccessKey,\n"
        code += "\(indt(3))region: region,\n"
        if let target = apiJSON["metadata"]["targetPrefix"].string {
            code += "\(indt(3))amzTarget: \"\(target)\",\n"
        }
        code += "\(indt(3))service: \"\(endpointPrefix)\",\n"

        code += "\(indt(3))serviceProtocol: \(serviceProtocol.instantiationCode()),\n"
        code += "\(indt(3))apiVersion: \"\(version)\",\n"
        code += "\(indt(3))endpoint: endpoint,\n"

        let endpoints = serviceEndpoints.sorted { $0.key < $1.key }
        if endpoints.count > 0 {
            code += "\(indt(3))serviceEndpoints: ["
                for (i, endpoint) in endpoints.enumerated() {
                    code += "\"\(endpoint.key)\": \"\(endpoint.value)\""
                    if i < endpoints.count - 1 {
                        code += ", "
                    }
                }
            code += "],\n"
        }

        if let partitionEndpoint = partitionEndpoint {
            code += "\(indt(3))partitionEndpoint: \"\(partitionEndpoint)\",\n"
        }

        code += "\(indt(3))middlewares: \(middlewares)"
        if !errorShapeNames.isEmpty {
            code += ",\n"
            code += "\(indt(3))possibleErrorTypes: [\(serviceErrorName).self]"
        }
        code += "\n"
        code += indt(2)+")\n"
        code += "\(indt(1))}\n"
        code += "\n"
        for operation in operations {
            let functionCode = operation.generateSwiftFunctionCode()
                .components(separatedBy: "\n")
                .map({ indt(1)+$0 })
                .joined(separator: "\n")

            let comment = docJSON["operations"][operation.name].stringValue.tagStriped()
            comment.split(separator: "\n").forEach({
                code += "\(indt(1))///  \($0)\n"
            })
            code += functionCode
            code += "\n\n"
        }
        code += "\n"
        code += "}"

        return code
    }

    func generateMembers(_ structure: StructureShape) -> String {
        var code = ""

        func shape2Hint(shape: Shape) -> AWSShapeMember.Shape {
            var typeForHint: AWSShapeMember.Shape
            switch shape.type {
            case .structure:
                typeForHint = .structure
            case .list:
                typeForHint = .list
            case .map:
                typeForHint = .map
            case .enum:
                typeForHint = .enum
            case .boolean:
                typeForHint = .boolean
            case .blob:
                typeForHint = .blob
            case .double:
                typeForHint = .double
            case .float:
                typeForHint = .float
            case .long:
                typeForHint = .long
            case .integer:
                typeForHint = .integer
            case .string:
                typeForHint = .string
            case .timestamp:
                typeForHint = .timestamp
            case .unhandledType:
                typeForHint = .any
            }

            return typeForHint
        }

        let hints: [String] = structure.members.map({ member in
            let hint = shape2Hint(shape: member.shape)

            var code = ""
            code += "\(indt(3))AWSShapeMember(label: \"\(member.name)\""
            if let location = member.location?.enumStyleDescription() {
                code += ", location: \(location)"
            }
            code += ", required: \(member.required), type: \(hint.enumStyleDescription)"
            if let encoding = member.shapeEncoding?.enumStyleDescription() {
                code += ", encoding: \(encoding)"
            }
            code += ")"
            return code
        })
        if hints.count > 0 {
            code += "\(indt(2))public static var _members: [AWSShapeMember] = ["
            code += "\n"
            code += hints.joined(separator: ", \n")
            code += "\n"
            code += "\(indt(2))]"
            code += "\n"
        }
        return code
    }

    func generateShapesCode() -> String {
        var code = ""
        code += autoGeneratedHeader
        code += "import Foundation\n"
        code += "import AWSSDKSwiftCore\n\n"
        code += "extension \(serviceName) {\n\n"

        for shape in shapes {
            if errorShapeNames.contains(shape.name) { continue }
            switch shape.type {
            case .enum(let values):
                code += "\(indt(1))public enum \(shape.name.toSwiftClassCase().reservedwordEscaped()): String, CustomStringConvertible, Codable {\n"
                for value in values {
                    var key = value.lowercased()
                        .replacingOccurrences(of: ".", with: "_")
                        .replacingOccurrences(of: ":", with: "_")
                        .replacingOccurrences(of: "-", with: "_")
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: "(", with: "_")
                        .replacingOccurrences(of: ")", with: "_")
                        .replacingOccurrences(of: "*", with: "all")

                    if Int(String(key[key.startIndex])) != nil { key = "_"+key }

                    let caseName = key.camelCased().reservedwordEscaped()
                    if caseName.allLetterIsNumeric() {
                        code += "\(indt(2))case \(shape.name.toSwiftVariableCase())\(caseName) = \"\(value)\"\n"
                    } else {
                        code += "\(indt(2))case \(caseName) = \"\(value)\"\n"
                    }
                }
                code += "\(indt(2))public var description: String { return self.rawValue }\n"
                code += "\(indt(1))}"
                code += "\n\n"

            case .structure(let type):
                let hasRecursiveOwnReference = type.members.contains(where: {
                    return $0.shape.swiftTypeName == shape.swiftTypeName
                            || $0.shape.swiftTypeName == "[\(shape.swiftTypeName)]"
                })

                let classOrStruct = hasRecursiveOwnReference ? "class" : "struct"
                code += "\(indt(1))public \(classOrStruct) \(shape.swiftTypeName): AWSShape {\n"
                if let payload = type.payload {
                    code += "\(indt(2))/// The key for the payload\n"
                    code += "\(indt(2))public static let payloadPath: String? = \"\(payload)\"\n"
                }

                code += "\(generateMembers(type))"

                for member in type.members {
                    if let comment = shapeDoc[shape.name]?[member.name], !comment.isEmpty {
                        comment.split(separator: "\n").forEach({
                            code += "\(indt(2))/// \($0)\n"
                        })
                    }
                    code += "\(indt(2))public \(member.toSwiftImmutableMemberSyntax())\n"
                }
                code += "\n"
                code += "\(indt(2))public init(\(type.members.toSwiftArgumentSyntax())) {\n"
                for member in type.members {
                    code += "\(indt(3))self.\(member.name.toSwiftVariableCase()) = \(member.name.toSwiftVariableCase())\n"
                }
                code += "\(indt(2))}\n\n"

                if type.members.count > 0 {
                    // CoadingKyes
                    code += "\(indt(2))private enum CodingKeys: String, CodingKey {\n"

                    var usedLocationPath: [String] = []

                    for member in type.members {
                        let locationPath = member.location?.name ?? member.name
                        if usedLocationPath.contains(locationPath) {
                            code += "\(indt(3))// TODO this is temporary measure for avoiding CondingKey duplication.\n"
                            code += "\(indt(3))// Should decode duplidated paths with same type for JSON\n"
                            code += "\(indt(3))case \(member.name.toSwiftVariableCase()) = \"_\(locationPath)\""
                        } else {
                            code += "\(indt(3))case \(member.name.toSwiftVariableCase()) = \"\(locationPath)\""
                            usedLocationPath.append(locationPath)
                        }

                        code += "\n"
                    }

                    code += "\(indt(2))}\n"
                }

                code += "\(indt(1))}"

                code += "\n\n"

            default:
                continue
            }
        }

        code += "}"

        return code
    }
}


extension Collection where Iterator.Element == Member {
    public func toSwiftArgumentSyntax() -> String {
        return self.map({ $0.toSwiftArgumentSyntax() }).sorted { $0 < $1 }.joined(separator: ", ")
    }
}


extension Shape {
    public func toSwiftType() -> String {
        switch self.type {
        case .string(_):
            return "String"

        case .integer(_):
            return "Int32"

        case .structure(_):
            return name.toSwiftClassCase()

        case .boolean:
            return "Bool"

        case .list(let shape):
            return "[\(shape.swiftTypeName)]"

        case .map(key: let keyShape, value: let valueShape):
            return "[\(keyShape.swiftTypeName): \(valueShape.swiftTypeName)]"

        case .long(_):
            return "Int64"

        case .double(_):
            return "Double"

        case .float(_):
            return "Float"

        case .blob:
            return "Data"

        case .timestamp:
            return "TimeStamp"

        case .enum(_):
            return name.toSwiftClassCase()

        case .unhandledType:
            return "Any"
        }
    }
}

extension Shape {
    public var swiftTypeName: String {
        if isStruct {
            return name.toSwiftClassCase()
        }

        return toSwiftType()
    }
}

extension Member {
    public var swiftTypeName: String {
        return shape.swiftTypeName
    }
}

extension String {
    func allLetterIsNumeric() -> Bool {
        for character in self {
            if let ascii = character.unicodeScalars.first?.value, (0x30..<0x39).contains(ascii) {
                continue
            } else {
                return false
            }
        }
        return true
    }
}
