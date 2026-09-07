//
//  Albums+WebDAV.swift
//  Nextcloud
//
//  Created by A200118228 on 07/07/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import NextcloudKit
import Alamofire
import SwiftyJSON
import SwiftyXMLParser

fileprivate extension DateFormatter {
    static let httpDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}

public extension NextcloudKit {
    
    // MARK: - Fetch all Albums
    func fetchAllAlbums(
        for account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[AlbumDTO], Error>) -> Void
    ) {
        
        let session = NCSession.shared.getSession(account: account)
        
        //options.contentType = "application/xml"
//        self.utilityFileSystem.getHomeServer(session: session)
        let urlPath = session.urlBase + "/remote.php/dav/photos/" + session.userId + "/albums/"
        
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = urlPath.encodedToUrl,
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        let method = HTTPMethod(rawValue: "PROPFIND")
        
        let propfindXML = """
        <?xml version="1.0"?>
        <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns" xmlns:ocs="http://open-collaboration-services.org/ns">
            <d:prop>
                <nc:last-photo />
                <nc:nbItems />
                <nc:location />
                <nc:dateRange />
                <nc:collaborators />
            </d:prop>
        </d:propfind>
        """
        
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = propfindXML.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }
        
        nkSession.sessionData.request(
            urlRequest,
            //interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)
        )
        .validate(statusCode: 200..<300)
        .onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }
        .response(queue: self.nkCommonInstance.backgroundQueue) { response in
            
            if NKLogFileManager.shared.logLevel.rawValue > 0 {
                debugPrint(response)
            }
            
            let statusCode = response.response?.statusCode
            
            // Explicit 404 check
            if statusCode == 404 {
                return options.queue.async {
                    completion(.success([]))
                }
            }
            
            switch response.result {
                
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }
                
            case .success:
                
                guard let data = response.data else {
                    return options.queue.async {
                        completion(.failure(NKError.invalidData))
                    }
                }
                
                let albums = self.parseAlbumsXML(data: data)
                options.queue.async {
                    completion(.success(albums))
                }
            }
        }
    }
    
    private func parseAlbumsXML(data: Data) -> [AlbumDTO] {
        
        let xml = XML.parse(data)
        var albums: [AlbumDTO] = []
        
        let elements = xml["d:multistatus", "d:response"]
        
        for element in elements {
            
            let href = element["d:href"].element?.text ?? ""
            
            let prop = element["d:propstat"]["d:prop"]
            
            let lastPhoto = prop["nc:last-photo"].element?.text
            let nbItems = prop["nc:nbItems"].element?.text.flatMap { Int($0) }
            let location = prop["nc:location"].element?.text
            let dateRange = prop["nc:dateRange"].element?.text
            let collaborators = prop["nc:collaborators"].element?.text
            
            // Optionally skip entries with 404 status
            let status = element["d:propstat"]["d:status"].element?.text ?? ""
            if status.contains("200") {
                let album = AlbumDTO(
                    href: href,
                    lastPhotoId: lastPhoto,
                    itemCount: nbItems,
                    location: location,
                    dateRange: dateRange,
                    collaborators: collaborators
                )
                albums.append(album)
            }
        }
        
        return albums
    }
    
    // MARK: - Create new Album
    func createNewAlbum(
        for account: String,
        albumName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<Bool, NKError>) -> Void
    ) {
        
        let session = NCSession.shared.getSession(account: account)
        
        let urlPath = session.urlBase + "/remote.php/dav/photos/" + session.userId + "/albums/\(albumName)/"

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = urlPath.encodedToUrl,
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        let method = HTTPMethod(rawValue: "MKCOL")
        
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }
        
        nkSession.sessionData.request(
            urlRequest,
            //interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)
        )
        //        .validate(statusCode: 200..<300)
        .onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }
        .response(queue: self.nkCommonInstance.backgroundQueue) { response in
            
            if NKLogFileManager.shared.logLevel.rawValue > 0 {
                debugPrint(response)
            }
            
            // Explicit 405 check -> treat as conflict (album already exists)
            if let statusCode = response.response?.statusCode, statusCode == 405 {
                // Resolve localized message so UI using `localizedDescription` shows the proper text
                let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                // Build an NSError carrying the localized description
                let nsError = NSError(
                    domain: "NextcloudKit",
                    code: NCGlobal.shared.errorConflict,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
                let error = NKError(error: nsError)
                return options.queue.async {
                    completion(.failure(error))
                }
            }
            
            guard let statusCode = response.response?.statusCode, (200...299).contains(statusCode) else {
                let code = response.response?.statusCode ?? -1
                let httpError = NKError(errorCode: code, errorDescription: "HTTP error \(code)", responseData: response.data)
                return options.queue.async {
                    completion(.failure(httpError))
                }
            }
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }
                
            case .success:
                options.queue.async {
                    completion(.success(true))
                }
            }
        }
    }
    
    // MARK: - Fetch Album photos
    func fetchAlbumPhotos(
        for album: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[AlbumPhotoDTO], Error>) -> Void
    ) {
        
        let session = NCSession.shared.getSession(account: account)
        
        let urlPath = session.urlBase + "/remote.php/dav/photos/" + session.userId + "/albums/" + album + "/"
        
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = urlPath.encodedToUrl,
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        let method = HTTPMethod(rawValue: "PROPFIND")
        
        let propfindXML = """
        <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns"
        xmlns:nc="http://nextcloud.org/ns" xmlns:ocs="http://open-collaborationservices.org/ns">
         <d:prop>
         <d:getcontentlength />
         <d:getcontenttype />
         <d:getetag />
         <d:getlastmodified />
         <d:resourcetype />
         <nc:metadata-photos-size />
         <nc:metadata-photos-original_date_time />
         <nc:metadata-files-live-photo />
         <nc:has-preview />
         <nc:hidden />
         <oc:favorite />
         <oc:fileid />
         <oc:permissions />
         </d:prop>
        </d:propfind>
        """
        
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = propfindXML.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }
        
        nkSession.sessionData.request(
            urlRequest,
            //interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)
        )
        .validate(statusCode: 200..<300)
        .onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }
        .response(queue: self.nkCommonInstance.backgroundQueue) { response in
            
            if NKLogFileManager.shared.logLevel.rawValue > 0 {
                debugPrint(response)
            }
            
            let statusCode = response.response?.statusCode
            
            // Explicit 404 check
            if statusCode == 404 {
                return options.queue.async {
                    completion(.success([]))
                }
            }
            
            switch response.result {
                
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }
                
            case .success:
                
                guard let data = response.data else {
                    return options.queue.async {
                        completion(.failure(NKError.invalidData))
                    }
                }
                
                let photos = self.parseAlbumPhotosXML(data: data)
                options.queue.async {
                    completion(.success(photos))
                }
            }
        }
    }
    
    private func parseAlbumPhotosXML(data: Data) -> [AlbumPhotoDTO] {
        
        let xml = XML.parse(data)
        var photos: [AlbumPhotoDTO] = []
        
        let elements = xml["d:multistatus", "d:response"]
        
        for element in elements {
            
            let href = element["d:href"].element?.text ?? ""
            let fileName = URL(string: href)?.lastPathComponent ?? href
            
            let propstats: [XML.Element] = element["d:propstat"].all ?? []
            
            for propstat in propstats {
                
                let ps = XML.Accessor(propstat)
                
                let status = ps["d:status"].element?.text ?? ""
                guard status.contains("200") else { continue }
                
                let prop = ps["d:prop"]
                
                guard let fileId = prop["oc:fileid"].element?.text else { continue }
                
                let contentType = prop["d:getcontenttype"].element?.text ?? ""
                let contentLength = prop["d:getcontentlength"].element?.text.flatMap { Int($0) } ?? 0
                let lastModified = prop["d:getlastmodified"].element?.text.flatMap {
                    DateFormatter.httpDate.date(from: $0)
                } ?? Date()
                
                let hasPreview = prop["nc:has-preview"].element?.text == "true"
                let isHidden = prop["nc:hidden"].element?.text == "true"
                let isFavorite = prop["oc:favorite"].element?.text == "1"
                let permissions = prop["oc:permissions"].element?.text ?? ""
                
                let originalDateTime = prop["nc:metadata-photos-original_date_time"]
                    .element?.text.flatMap { Double($0) }
                    .flatMap { Date(timeIntervalSince1970: $0) }
                
                let sizeNode = prop["nc:metadata-photos-size"]
                let width = sizeNode["width"].element?.text.flatMap { Int($0) }
                let height = sizeNode["height"].element?.text.flatMap { Int($0) }
                
                let photo = AlbumPhotoDTO(
                    fileId: fileId,
                    fileName: fileName,
                    contentType: contentType,
                    contentLength: contentLength,
                    lastModified: lastModified,
                    hasPreview: hasPreview,
                    isHidden: isHidden,
                    isFavorite: isFavorite,
                    permissions: permissions,
                    originalDateTime: originalDateTime,
                    width: width,
                    height: height
                )
                
                photos.append(photo)
            }
        }
        
        return photos
    }
    
    // MARK: - Copy Photo to Album
    func copyPhotoToAlbum(
        account: String,
        sourcePath: String,
        albumName: String,
        fileName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        
        let session = NCSession.shared.getSession(account: account)
//        
        let sourceUrlString: String = {
            if sourcePath.lowercased().hasPrefix("http") {
                return sourcePath
            } else {
                return session.urlBase + sourcePath
            }
        }()
        
        let destinationPath = "/remote.php/dav/photos/" + session.userId + "/albums/" + albumName + "/" + fileName
        
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
            let sourceUrl = sourceUrlString.encodedToUrl,
            var headers = nkCommonInstance.getStandardHeaders(account: account, options: options)
        else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        headers.add(
            name: "Destination",
            value: destinationPath.urlEncoded ?? destinationPath
        )
        
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: sourceUrl, method: .init(rawValue: "COPY"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }
        
        nkSession.sessionData.request(urlRequest)
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .response(queue: self.nkCommonInstance.backgroundQueue) { response in
                if NKLogFileManager.shared.logLevel.rawValue > 0 {
                    debugPrint(response)
                }
        
                let statusCode = response.response?.statusCode
                
                // Explicit 404 check
                if statusCode == NCGlobal.shared.errorResourceNotFound || statusCode == NCGlobal.shared.errorForbidden {
//                if statusCode == 404 {
                    return options.queue.async {
                        completion(.success(()))
                    }
                }
                
                switch response.result {
                case .failure(let error):
                    let nkErr = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async { completion(.failure(nkErr)) }
                    
                case .success:
                    options.queue.async { completion(.success(())) }
                }
            }
    }
    
    // MARK: - Delete Photo from Album
    
    /// Asynchronously deletes a Photo FromAlbum from the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the file or folder to delete.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - responseData: The raw Alamofire response data.
    ///   - error: The `NKError` result indicating success or failure.
    func deletePhotoFromAlbumAsync(albumName: String,
                                   fileName: String,
                                   serverUrlFileName: String,
                                   account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            deletePhotoFromAlbum(albumName: albumName,
                               fileName: fileName,
                               serverUrlFileName: serverUrlFileName,
                               account: account,
                               options: options,
                               taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
    
    /// Deletes a Photo From Album from the Nextcloud server at the specified URL.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the file or folder to delete.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - responseData: The raw Alamofire response data.
    ///     - error: The `NKError` result indicating success or failure.
    func deletePhotoFromAlbum(albumName: String,
                            fileName: String,
                            serverUrlFileName: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let session = NCSession.shared.getSession(account: account)

        // Build URL by appending path components to avoid double-encoding (e.g., %2520)
        guard var baseUrl = URL(string: session.urlBase) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        baseUrl.appendPathComponent("remote.php")
        baseUrl.appendPathComponent("dav")
        baseUrl.appendPathComponent("photos")
        baseUrl.appendPathComponent(session.userId)
        baseUrl.appendPathComponent("albums")
        baseUrl.appendPathComponent(albumName)
        baseUrl.appendPathComponent(fileName)
        let url = baseUrl

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            // Inline evaluation to avoid calling inaccessible helper
            let resultError: NKError
            if let statusCode = response.response?.statusCode {
                if (200...299).contains(statusCode) {
                    resultError = .success
                } else if statusCode == NCGlobal.shared.errorResourceNotFound { // 404 - already not in album
                    resultError = .success
                } else {
                    // Non-2xx, non-404: derive from AFError if present, else map to HTTP error
                    if let afError = response.error {
                        resultError = NKError(error: afError, afResponse: response, responseData: response.data)
                    } else {
                        resultError = NKError(errorCode: statusCode, errorDescription: "HTTP error \(statusCode)", responseData: response.data)
                    }
                }
            } else if let afError = response.error {
                resultError = NKError(error: afError, afResponse: response, responseData: response.data)
            } else {
                resultError = NKError.invalidResponseError
            }

            options.queue.async {
                completion(account, response, resultError)
            }
        }
    }
    
    // MARK: - Delete Album
    func deleteAlbum(
        albumName: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
//        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        completion: @escaping (Result<Void, Error>) -> Void) {
        
        let session = NCSession.shared.getSession(account: account)
        
        let urlPath = session.urlBase + "/remote.php/dav/photos/" + session.userId + "/albums/" + albumName
        
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = urlPath.encodedToUrl,
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        let method = HTTPMethod.delete
        
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }
        
        nkSession.sessionData.request(urlRequest)
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .response(queue: self.nkCommonInstance.backgroundQueue) { response in
                
                if NKLogFileManager.shared.logLevel.rawValue > 0 {
                    debugPrint(response)
                }
                
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async { completion(.failure(error)) }
                    
                case .success:
                    options.queue.async { completion(.success(())) }
                }
            }
    }
    
    // MARK: - Rename Album
    func renameAlbum(
        account: String,
        from oldName: String,
        to newName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let session = NCSession.shared.getSession(account: account)
        
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        let urlPath = session.urlBase + "/remote.php/dav/photos/" + session.userId + "/albums/" + oldName + "/"
        let destinationHeader = "/remote.php/dav/photos/" + session.userId + "/albums/" + newName + "/"
        
        guard let url = urlPath.encodedToUrl,
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        
        // Add the required MOVE header
        headers.add(
            name: "Destination",
            value: destinationHeader.addingPercentEncoding(
                withAllowedCharacters: CharacterSet.urlQueryAllowed.subtracting(["+", "?", "&"])
            ) ?? destinationHeader
        )
        // Disallow overwriting an existing destination to avoid silent data loss
        headers.add(name: "Overwrite", value: "F")
        
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .init(rawValue: "MOVE"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }
        
        nkSession.sessionData.request(urlRequest)
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .response(queue: self.nkCommonInstance.backgroundQueue) { response in
                if NKLogFileManager.shared.logLevel.rawValue > 0 {
                    debugPrint(response)
                }
                
                // If server signals that destination already exists, surface a conflict error to the UI
                if let statusCode = response.response?.statusCode, statusCode == 412 || statusCode == 409 {
                    let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                    let nsError = NSError(
                        domain: "NextcloudKit",
                        code: NCGlobal.shared.errorConflict,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                    let error = NKError(error: nsError)
                    return options.queue.async { completion(.failure(error)) }
                }
                
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async { completion(.failure(error)) }
                    
                case .success:
                    options.queue.async { completion(.success(())) }
                }
            }
    }
}

