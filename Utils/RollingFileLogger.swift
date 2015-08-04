/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import XCGLogger

//// A rolling file loggers that saves to a different log file based on given timestamp
public class RollingFileLogger: XCGLogger {

    private static let FiveMbsInBytes: UInt64 = 5 * 100000
    private let sizeLimit: UInt64
    private let logDirectoryPath: String?

    let fileLogIdentifierPrefix = "com.mozilla.firefox.filelogger."
    let consoleLogIdentifierPrefix = "com.mozilla.firefox.consolelogger."

    private static let DateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss_z"
        return formatter
    }()

    let root: String

    init(filenameRoot: String, logDirectoryPath: String?, sizeLimit: UInt64 = FiveMbsInBytes) {
        root = filenameRoot
        self.sizeLimit = sizeLimit
        self.logDirectoryPath = logDirectoryPath
        super.init()
        addLogDestination(XCGConsoleLogDestination(owner: self, identifier: consoleLogIdentifierWithRoot(root)))
    }

    /**
    Create a new log file with the given timestamp to log events into

    :param: date Date for with to start and mark the new log file
    */
    public func newLogWithDate(date: NSDate) {
        // Don't start a log if we don't have a valid log directory path
        if logDirectoryPath == nil {
            return
        }

        // Before we create a new log file, check to see we haven't hit our size limit and if we did, clear out some logs to make room
        while sizeOfAllLogFiles() > sizeLimit {
            deleteOldestLog()
        }

        if let filename = filenameWithRoot(root, withDate: date) {
            removeLogDestination(fileLogIdentifierWithRoot(root))
            addLogDestination(XCGFileLogDestination(owner: self, writeToFile: filename, identifier: fileLogIdentifierWithRoot(root)))
            info("Created file destination for logger with root: \(self.root) and timestamp: \(date)")
        } else {
            error("Failed to create a new log with root name: \(self.root) and timestamp: \(date)")
        }
    }

    private func deleteOldestLog() {
        var logFiles = savedLogFilenames()
        logFiles.sort { $0 < $1 }

        if let oldestLogFilename = logFiles.first,
           let dir = logDirectoryPath {
            NSFileManager.defaultManager().removeItemAtPath("\(dir)/\(oldestLogFilename)", error: nil)
        }
    }

    private func savedLogFilenames() -> [String] {
        if logDirectoryPath == nil {
            return []
        }

        if var logFiles = NSFileManager.defaultManager().contentsOfDirectoryAtPath(logDirectoryPath!, error: nil) as? [String] {
            return logFiles.filter { $0.startsWith("\(self.root).") }
        } else {
            return []
        }
    }

    private func sizeOfAllLogFiles() -> UInt64 {
        if logDirectoryPath == nil {
            return 0
        }

        return savedLogFilenames().reduce(0) {
            if let attributes = NSFileManager.defaultManager().attributesOfItemAtPath("\(logDirectoryPath!)/\($0.1)", error: &error) {
               return (attributes[NSFileSize] as! NSNumber).unsignedLongLongValue
            } else {
                return 0
            }
        }
    }

    private func filenameWithRoot(root: String, withDate date: NSDate) -> String? {
        if let dir = logDirectoryPath {
            return "\(dir)/\(root).\(RollingFileLogger.DateFormatter.stringFromDate(date)).log"
        } else {
            return nil
        }
    }

    private func fileLogIdentifierWithRoot(root: String) -> String {
        return "\(fileLogIdentifierPrefix).\(root)"
    }

    private func consoleLogIdentifierWithRoot(root: String) -> String {
        return "\(consoleLogIdentifierPrefix).\(root)"
    }
}
