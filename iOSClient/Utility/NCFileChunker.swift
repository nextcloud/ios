//
//  NCFileChunker.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

public class NCFileChunker {
    
    let input:URL
    let outputDirectory:URL
    let chunkSize:Int
    let bufferSize:Int
    
    init( input:URL, outputDirectory:URL, chunkSize:Int, bufferSize:Int = 1024 ) {
        self.input = input
        self.outputDirectory = outputDirectory
        self.chunkSize = chunkSize
        self.bufferSize = bufferSize
    }
    
    func chunk( )throws->[URL] {
        
        let fileManager:FileManager = .default
        
        var isDirectory:ObjCBool = false
        if !fileManager.fileExists( atPath:outputDirectory.path, isDirectory:&isDirectory ) {
            try fileManager.createDirectory( at:outputDirectory, withIntermediateDirectories:true, attributes:nil )
        }
        
        var urls:[URL] = [ ]
        let processInfo:ProcessInfo = .init( )
        let reader:FileHandle = try .init( forReadingFrom:input )
        var writer:FileHandle?
        var buffer:Data?
        var chunk:Int = 0
        
        repeat {
            
            if chunk >= chunkSize {
                writer?.closeFile()
                //try writer?.close( )
                writer = nil
                chunk = 0
            }
            
            
            let chunkRemaining:Int = chunkSize - chunk
            buffer = reader.readData(ofLength: min( bufferSize, chunkRemaining ))
            //buffer = try reader.read( upToCount:min( bufferSize, chunkRemaining ) )
            
            if let buffer = buffer {
                
                if writer == nil {
                    
                    let outputURL = outputDirectory.appendingPathComponent( processInfo.globallyUniqueString ).appendingPathExtension( "chunk" )
                    fileManager.createFile( atPath:outputURL.path, contents:nil, attributes:nil )
                    writer = try .init( forWritingTo:outputURL )
                    urls.append( outputURL )
                }
                
                writer?.write( buffer )
                chunk = chunk + buffer.count
            }
        }
        while buffer != nil
        
        //try reader.close( )
        reader.closeFile()
        return urls
    }
    
}

extension URL
{
    public func chunk( to outputDirectory:URL, chunkSize:Int, bufferSize:Int = 1024 )throws->[URL] {
        let chunker:NCFileChunker = .init(input:self, outputDirectory:outputDirectory, chunkSize:chunkSize, bufferSize:bufferSize )
        return try chunker.chunk( )
    }
}
