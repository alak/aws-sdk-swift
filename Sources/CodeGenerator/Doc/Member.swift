//
//  Member.swift
//  AWSSDKSwift
//
//  Created by Yuki Takei on 2017/03/29.
//
//

import Foundation

public enum ShapeEncoding {
    case `default`
    case flatList
    case list(member: String)
    case flatMap(key: String, value: String)
    case map(entry: String, key: String, value: String)
}

public struct Member {
    public let name: String
    public let required: Bool
    public let shape: Shape
    public let location: Location?
    public let shapeEncoding: ShapeEncoding?
    public let locationName: String?
    public let xmlNamespace: XMLNamespace?
    public let isStreaming: Bool
    
    public init(name: String, required: Bool, shape: Shape, location: Location?, locationName: String?, shapeEncoding: ShapeEncoding?, xmlNamespace: XMLNamespace?, isStreaming: Bool){
        self.name = name
        self.required = required
        self.shape = shape
        self.location = location
        self.locationName = locationName
        self.shapeEncoding = shapeEncoding
        self.xmlNamespace = xmlNamespace
        self.isStreaming = isStreaming
    }
}
