//
//  SBFileManager.swift
//  SBFileManager
//
//  Created by LiDehua on 16/10/13.
//  Copyright © 2016年 LiDehua. All rights reserved.
//

import UIKit

extension FileManager {
    func homeDir() -> String {
        return NSHomeDirectory()
    }
    
    func documentsDir() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }
    
    func libraryDir() -> String {
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
    }
    
    func preferencesDir() -> String {
        return libraryDir().appending("/Preferences")
    }
    
    func cacheDir() -> String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
    }
    
    func tmpDir() -> String {
        return NSTemporaryDirectory()
    }
    
    func listFiles(atPath: String, deep: Bool) -> [String]? {
        if deep {
            do {
                let paths = try self.subpathsOfDirectory(atPath: atPath)
                return paths
            } catch _ as NSError { fatalError() }
        } else {
            do {
                let paths = try self.contentsOfDirectory(atPath: atPath)
                return paths
            } catch _ as NSError { fatalError() }
        }
    }
    
    func listFilesAtHome(deep: Bool) -> [String]? {
        return listFiles(atPath: homeDir(), deep: deep)
    }
    
    func listFilesAtLibrary(deep: Bool) -> [String]? {
        return listFiles(atPath: libraryDir(), deep: deep)
    }
    
    func listFilesAtDocuments(deep: Bool) -> [String]? {
        return listFiles(atPath: documentsDir(), deep: deep)
    }
    
    func listFilesAtCache(deep: Bool) -> [String]? {
        return listFiles(atPath: cacheDir(), deep: deep)
    }
    
    func listFilesAtTmp(deep: Bool) -> [String]? {
        return listFiles(atPath: tmpDir(), deep: deep)
    }
    
    func attributeOfItem(atPath: String, forKey: FileAttributeKey) throws -> Any? {
        do {
            let attribute = try self.attributesOfItem(atPath: atPath)
            return attribute[forKey]
        } catch { return nil }
    }
    func createDirectory(atPath: String) throws -> Bool {
        do {
            _ = try self.createDirectory(at: URL(fileURLWithPath: atPath), withIntermediateDirectories: true, attributes: nil)
            return true
        } catch let error as NSError {
            throw(error)
        }
    }
    func createFile(atPath: String, write: Any? = nil, overwrite: Bool = true) throws -> Bool {
        do {
            if isDirecotory(atPath: atPath) { return false }
            if !overwrite, self.fileExists(atPath: atPath) { return false }
            do {
                if try !self.createFile(atPath: atPath) { return false }
                guard let content = write else { return false }
                do {
                    return try writeFile(atPath: atPath, with: content)
                }
            }
        } catch let error as NSError { throw(error) }
    }
    
    func creationDate(atPath: String) throws -> Date? {
        do {
            guard let date = try self.attributeOfItem(atPath: atPath, forKey: FileAttributeKey.creationDate) as? Date else { return nil }
            return date
        } catch let error as NSError { throw(error) }
    }
    
    func modificationDate(atPath: String) throws -> Date? {
        do {
            guard let date = try self.attributeOfItem(atPath: atPath, forKey: FileAttributeKey.modificationDate) as? Date else { return nil }
            return date
        } catch let error as NSError { throw(error) }
    }
    
    func clearDirectory(atPath: String) throws -> Bool {
        guard let paths = self.listFiles(atPath: atPath, deep: false) else { return false }
        var result = true
        for path in paths {
            do {
                try removeItem(atPath: atPath.appending("/\(path)"))
            } catch let error as NSError { result = false; throw(error) }
        }
        return result
    }
    
    func sizeOfItem(atPath: String, with formatter: ByteCountFormatter.Units) throws -> Float {
        do {
            var totalSize: Float
            if isDirecotory(atPath: atPath) {
                guard let paths = listFiles(atPath: atPath, deep: true) else { return 0 }
                var size: Float = 0.0
                for path in paths {
                    if isDirecotory(atPath: (atPath + "/" + path)) { continue }
                    guard let si = try attributeOfItem(atPath: (atPath + "/" + path), forKey: FileAttributeKey.size) as? Float else { continue }
                    size += si
                }
                totalSize = size
            } else {
                guard let size = try attributeOfItem(atPath: atPath, forKey: FileAttributeKey.size) as? Float else { return 0 }
                totalSize = size
            }
            totalSize /= powf(1000, Float(formatter.rawValue / 2))
            return totalSize
        } catch let error as NSError { throw(error) }
    }

    func writeFile(atPath: String, with Content: Any) throws -> Bool {
        var result = true
        switch Content {
        case is NSArray, is Array<Any>:
            result = (Content as! NSArray).write(to: URL(fileURLWithPath: atPath), atomically: true)
        case is NSDictionary, is Dictionary<AnyHashable, AnyObject>:
            result = (Content as! NSDictionary).write(to: URL(fileURLWithPath: atPath), atomically: true)
        case is NSData, is Data:
            result = (Content as! NSData).write(to: URL(fileURLWithPath: atPath), atomically: true)
        case is NSString, is String:
            do {
                try (Content as! NSString).write(to: URL(fileURLWithPath: atPath), atomically: true, encoding: String.Encoding.utf8.rawValue)
            } catch let error as NSError { result = false; throw(error) }
        case is UIImage:
            do {
                try UIImagePNGRepresentation(Content as! UIImage)?.write(to: URL(fileURLWithPath: atPath))
            } catch let error as NSError { result = false; throw(error) }
        case is NSCoding:
            result = NSKeyedArchiver.archiveRootObject(Content, toFile: atPath)
        default:
            result = false
            throw(NSError(domain: "com.SBFileManager", code: 4, userInfo: ["errorDescription": "无法识别的对象"]))
        }
        return result
    }
    
    func sb_copyItem(atPath: String, to path: String, overwrite: Bool = false) throws -> Bool {
        if !fileExists(atPath: atPath) { return false }
        let url = NSURL(fileURLWithPath: atPath)
        let toPathDirectory = url.deletingLastPathComponent?.path
        if !fileExists(atPath: toPathDirectory!) {
            do {
                _ = try createDirectory(atPath: toPathDirectory!)
            } catch let error as NSError { throw(error) }
        }
        if overwrite, fileExists(atPath: path) {
            do {
                try removeItem(atPath: path)
            } catch let error as NSError { throw(error) }
        }
        do {
            try copyItem(atPath: atPath, toPath: path)
        } catch let error as NSError { throw(error) }
        return true
    }
    
    func sb_moveItem(atPath: String, to path: String, overwrite: Bool = false) throws -> Bool {
        if !fileExists(atPath: atPath) { return false }
        let url = NSURL(fileURLWithPath: atPath)
        let toPathDirectory = url.deletingLastPathComponent?.path
        if !fileExists(atPath: toPathDirectory!) {
            do {
                _ = try createDirectory(atPath: toPathDirectory!)
            } catch let error as NSError { throw(error) }
        }
        if fileExists(atPath: path), overwrite {
            do { try removeItem(atPath: path) } catch let error as NSError { throw(error) }
        }
        
        do {
            try moveItem(atPath: atPath, toPath: path)
        } catch let error as NSError { throw(error) }
        return true
    }
    
    func isDirecotory(atPath: String) -> Bool {
        do {
            let attribute = try self.attributesOfItem(atPath: atPath)
            return attribute[FileAttributeKey.type] as! FileAttributeType == .typeDirectory
        } catch { return false }
    }
}
