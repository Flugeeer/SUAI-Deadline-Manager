//
//  ScheduleService.swift
//  ScheduleService
//
//  Created by Vladislav Katashov on 06.11.2026.
//

import Foundation

struct ScheduleService {
    private let baseURL = URL(string: "https://guap.ru/rasp")!

    func loadCatalog() async throws -> ScheduleCatalog {
        let html = try await loadHTML(from: baseURL)
        return ScheduleHTMLParser().parseCatalog(html)
    }

    func loadSchedule(for criteria: ScheduleCriteria) async throws -> [ScheduleDay] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []

        if let group = criteria.group {
            items.append(URLQueryItem(name: "gr", value: group.id))
        }
        if let teacher = criteria.teacher {
            items.append(URLQueryItem(name: "pr", value: teacher.id))
        }
        if let chair = criteria.chair {
            items.append(URLQueryItem(name: "ch", value: chair.id))
        }
        if let room = criteria.room {
            items.append(URLQueryItem(name: "ad", value: room.id))
        }

        components.queryItems = items
        let html = try await loadHTML(from: components.url!)
        return ScheduleHTMLParser().parseSchedule(html)
    }

    private func loadHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("SUAIDeadlineManager/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return html
    }
}

struct ScheduleHTMLParser {
    func parseCatalog(_ html: String) -> ScheduleCatalog {
        ScheduleCatalog(
            groups: options(in: html, selectID: "selGroup"),
            teachers: options(in: html, selectID: "selPrep"),
            chairs: options(in: html, selectID: "selChair"),
            rooms: options(in: html, selectID: "selRoom")
        )
    }

    func parseSchedule(_ html: String) -> [ScheduleDay] {
        let headings = matches(
            pattern: #"<h4[^>]*>(.*?)</h4>"#,
            in: html,
            options: [.dotMatchesLineSeparators]
        )

        return headings.enumerated().compactMap { index, heading in
            guard heading.numberOfRanges > 1 else { return nil }
            let dayName = clean(fragment: substring(html, range: heading.range(at: 1)))
            let headingRange = heading.range(at: 0)
            let start = headingRange.location + headingRange.length
            let end = index + 1 < headings.count ? headings[index + 1].range(at: 0).location : html.utf16.count
            guard end > start else { return nil }

            let segment = substring(html, range: NSRange(location: start, length: end - start))
            let lessons = parseLessons(in: segment)
            return lessons.isEmpty ? nil : ScheduleDay(name: dayName, lessons: lessons)
        }
    }

    private func options(in html: String, selectID: String) -> [ScheduleOption] {
        let escapedID = NSRegularExpression.escapedPattern(for: selectID)
        let selectPattern = #"<select[^>]*id="\#(escapedID)"[^>]*>(.*?)</select>"#
        guard let selectMatch = firstMatch(
            pattern: selectPattern,
            in: html,
            options: [.dotMatchesLineSeparators]
        ), selectMatch.numberOfRanges > 1 else { return [] }

        let selectHTML = substring(html, range: selectMatch.range(at: 1))
        return matches(
            pattern: #"<option[^>]*value="([^"]*)"[^>]*>(.*?)</option>"#,
            in: selectHTML,
            options: [.dotMatchesLineSeparators]
        ).compactMap { match in
            guard match.numberOfRanges > 2 else { return nil }
            let id = substring(selectHTML, range: match.range(at: 1))
            let name = clean(fragment: substring(selectHTML, range: match.range(at: 2)))
            guard !id.isEmpty, !name.isEmpty, name != "–нет–" else { return nil }
            return ScheduleOption(id: id, name: name)
        }
    }

    private func parseLessons(in segment: String) -> [ScheduleLesson] {
        let tokenPattern = #"<div class="(?:mt-3 text-danger|mb-3 py-2 d-flex gap-2)">"#
        let tokens = matches(pattern: tokenPattern, in: segment)
        var pairNumber: String?
        var pairTime: String?
        var lessons: [ScheduleLesson] = []

        for (index, token) in tokens.enumerated() {
            let start = token.range(at: 0).location
            let end = index + 1 < tokens.count ? tokens[index + 1].range(at: 0).location : segment.utf16.count
            guard end > start else { continue }
            let block = substring(segment, range: NSRange(location: start, length: end - start))
            if block.contains("mt-3 text-danger") {
                if let pair = firstMatch(
                    pattern: #"([0-9]+)\s*пара.*?\(([^<]+)\)"#,
                    in: block,
                    options: [.dotMatchesLineSeparators]
                ), pair.numberOfRanges > 2 {
                    pairNumber = clean(fragment: substring(block, range: pair.range(at: 1)))
                    pairTime = clean(fragment: substring(block, range: pair.range(at: 2)))
                }
                continue
            }

            guard let kind = content(ofClassContaining: "fs-6", in: block),
                  let subject = content(ofClassContaining: "lead", in: block) else { continue }

            let links = parseLinks(in: block)
            let week: LessonWeek
            if block.contains("week1") {
                week = .upper
            } else if block.contains("week2") {
                week = .lower
            } else {
                week = .every
            }

            lessons.append(
                ScheduleLesson(
                    pairNumber: pairNumber,
                    time: pairTime,
                    week: week,
                    kind: kind,
                    subject: subject,
                    room: links.first(where: { $0.key == "ad" })?.name,
                    chair: links.first(where: { $0.key == "ch" })?.name,
                    teacher: links.first(where: { $0.key == "pr" })?.name,
                    groups: links.filter { $0.key == "gr" }.map { $0.name }
                )
            )
        }
        return lessons
    }

    private func content(ofClassContaining className: String, in html: String) -> String? {
        let escapedClass = NSRegularExpression.escapedPattern(for: className)
        let pattern = #"<div class="[^"]*\#(escapedClass)[^"]*">(.*?)</div>"#
        guard let match = firstMatch(pattern: pattern, in: html, options: [.dotMatchesLineSeparators]),
              match.numberOfRanges > 1 else { return nil }
        let value = clean(fragment: substring(html, range: match.range(at: 1)))
        return value.isEmpty ? nil : value
    }

    private func parseLinks(in html: String) -> [(key: String, name: String)] {
        matches(
            pattern: #"<a[^>]*href="\?([a-z]+)=([^"]+)"[^>]*>(.*?)</a>"#,
            in: html,
            options: [.dotMatchesLineSeparators]
        ).compactMap { match in
            guard match.numberOfRanges > 3 else { return nil }
            return (
                substring(html, range: match.range(at: 1)),
                clean(fragment: substring(html, range: match.range(at: 3)))
            )
        }
    }

    private func clean(fragment: String) -> String {
        var value = fragment.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"",
            "&lt;": "<", "&gt;": ">", "&mdash;": "—", "&ndash;": "–"
        ]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        value = decodeNumericEntities(value)
        return value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeNumericEntities(_ value: String) -> String {
        var result = value
        let regex = try! NSRegularExpression(pattern: #"&#(x[0-9a-fA-F]+|[0-9]+);"#)
        for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
            guard match.numberOfRanges > 1,
                  let entityRange = Range(match.range(at: 1), in: result) else { continue }
            let raw = String(result[entityRange])
            let number = raw.lowercased().hasPrefix("x")
                ? UInt32(raw.dropFirst(), radix: 16)
                : UInt32(raw, radix: 10)
            guard let number, let scalar = UnicodeScalar(number),
                  let fullRange = Range(match.range(at: 0), in: result) else { continue }
            result.replaceSubrange(fullRange, with: String(scalar))
        }
        return result
    }

    private func matches(
        pattern: String,
        in string: String,
        options: NSRegularExpression.Options = []
    ) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        return regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
    }

    private func firstMatch(
        pattern: String,
        in string: String,
        options: NSRegularExpression.Options = []
    ) -> NSTextCheckingResult? {
        matches(pattern: pattern, in: string, options: options).first
    }

    private func substring(_ string: String, range: NSRange) -> String {
        guard let swiftRange = Range(range, in: string) else { return "" }
        return String(string[swiftRange])
    }
}
