//
// ChatLayout
// Cell.swift
// https://github.com/ekazaev/ChatLayout
//
// Created by Eugene Kazaev in 2020-2023.
// Distributed under the MIT license.
//
// Become a sponsor:
// https://github.com/sponsors/ekazaev
//

import ChatLayout
import DifferenceKit
import Foundation
import UIKit

enum Cell: Hashable {

    enum BubbleType {
        case normal
        case tailed
    }

    case message(Message, bubbleType: BubbleType)

    case typingIndicator

    case messageGroup(MessageGroup)

    case date(DateGroup)

    var alignment: ChatItemAlignment {
        switch self {
        case let .message(message, _):
            return message.type == .incoming ? .leading : .trailing
        case .typingIndicator:
            return .leading
        case let .messageGroup(group):
            return group.type == .incoming ? .leading : .trailing
        case .date:
            return .center
        }
    }

}

extension Cell: Differentiable {

    enum Identifier: Hashable {
        case message(UUID)

        case typingIndicator

        case messageGroup(UUID)

        case date(UUID)
    }


    public var differenceIdentifier: Identifier {
        switch self {
        case let .message(message, _):
            return .message(message.id)
        case .typingIndicator:
            return .typingIndicator
        case let .messageGroup(group):
            return .messageGroup(group.id)
        case let .date(group):
            return .date(group.id)
        }
    }

    public func isContentEqual(to source: Cell) -> Bool {
        self == source
    }

}
