//
//  RommServiceProvider.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/29/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import CloudServiceKit

class RommServiceProvider: CloudServiceProvider {
    var delegate: (any CloudServiceKit.CloudServiceProviderDelegate)?
    var refreshAccessTokenHandler: CloudServiceKit.CloudRefreshAccessTokenHandler?
    var credential: URLCredential?
    var name: String { "RomM" }

    private let client: RommClient?

    let serviceId: String

    /// Display-only metadata carried in `CloudItem.json`; `CloudItem.name` must stay the real file name.
    static let displayNameKey = "rommDisplayName"

    private let romContentPathTemplate = "/api/roms/{romID}/content/{fileName}"

    private func romContentPath(romID: Int, fileName: String) -> String {
        romContentPathTemplate
            .replacingOccurrences(of: "{romID}", with: "\(romID)")
            .replacingOccurrences(of: "{fileName}", with: fileName)
    }

    var rootItem: CloudServiceKit.CloudItem {
        CloudItem(id: name, name: name, path: "/", isDirectory: true)
    }

    struct RommDirectoryPage {
        let items: [CloudItem]
        let total: Int?
    }

    required init(credential: URLCredential?) {
        fatalError("Use init(service:)")
    }

    init(service: ImportService) {
        self.serviceId = "\(service.id)"
        self.client = RommClient(scheme: service.scheme ?? "http",
                                 host: service.host ?? "",
                                 port: service.port,
                                 user: service.user,
                                 password: service.password,
                                 path: service.path)
    }

    private func makeCloudItem(for rom: RommRom) -> CloudItem {
        let item = CloudItem(id: "\(rom.id)/\(rom.fs_name)",
                             name: rom.fs_name,
                             path: romContentPath(romID: rom.id, fileName: rom.fs_name),
                             isDirectory: false,
                             json: [Self.displayNameKey: rom.name ?? ""])
        item.size = rom.fs_size_bytes ?? 0
        return item
    }

    /// One page of ROMs for lazy loading and search in the file browser.
    func romPage(platformID: Int, searchTerm: String?, offset: Int, limit: Int) async throws -> RommDirectoryPage {
        guard let client else {
            throw ImportError.lanServiceInitFailed(serviceName: name)
        }
        let page = try await client.romPage(platformID: platformID,
                                            searchTerm: searchTerm,
                                            offset: offset,
                                            limit: limit)
        return RommDirectoryPage(items: page.items.map { makeCloudItem(for: $0) }, total: page.total)
    }

    func contentsOfDirectory(_ directory: CloudServiceKit.CloudItem,
                             completion: @escaping (Result<[CloudServiceKit.CloudItem], Error>) -> Void) {
        guard let client else {
            completion(.failure(ImportError.lanServiceInitFailed(serviceName: name)))
            return
        }
        Task {
            do {
                let items: [CloudItem]
                if directory.path == "/" {
                    items = try await client.platforms().map { platform in
                        CloudItem(id: "\(platform.id)",
                                  name: platform.name,
                                  path: "/\(platform.id)",
                                  isDirectory: true)
                    }
                } else {
                    let platformID = Int(directory.id) ?? 0
                    items = try await client.roms(platformID: platformID).map { rom in
                        makeCloudItem(for: rom)
                    }
                }
                await MainActor.run { completion(.success(items)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func downloadableRequest(of item: CloudItem) -> URLRequest? {
        guard !item.isDirectory else { return nil }
        return client?.request(path: item.path)
    }

    func attributesOfItem(_ item: CloudServiceKit.CloudItem, completion: @escaping (Result<CloudServiceKit.CloudItem, Error>) -> Void) {}

    func copyItem(_ item: CloudServiceKit.CloudItem, to directory: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    func createFolder(_ folderName: String, at directory: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    func getCloudSpaceInformation(completion: @escaping (Result<CloudServiceKit.CloudSpaceInformation, Error>) -> Void) {}

    func getCurrentUserInfo(completion: @escaping (Result<CloudServiceKit.CloudUser, Error>) -> Void) {}

    func moveItem(_ item: CloudServiceKit.CloudItem, to directory: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    func removeItem(_ item: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    func renameItem(_ item: CloudServiceKit.CloudItem, newName: String, completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    func searchFiles(keyword: String, completion: @escaping (Result<[CloudServiceKit.CloudItem], Error>) -> Void) {}

    func uploadData(_ data: Data, filename: String, to directory: CloudServiceKit.CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    func uploadFile(_ fileURL: URL, to directory: CloudServiceKit.CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudServiceKit.CloudCompletionHandler) {}

    static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? { nil }
}
