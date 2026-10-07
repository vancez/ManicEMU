//
//  ResourcesKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ZipArchive
import ZIPFoundation

struct ResourcesKit {
    static func loadResources(completion: ((Bool)->Void)? = nil) {
        //将bunle的加密文件解压到Library中
        
        //新版本更新需要强制刷新资源
        var forceRefresh = false
        if let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) {
            let appVersion = R.Config.AppVersion
            let appVersionNumber = UInt64(appVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            if systemCoreVersionNumber < appVersionNumber {
                //需要刷新
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Resource))
                forceRefresh = true
            } else {
                //检查一下build version是否更新
                let systemCoreBuildVersion = UserDefaults.standard.integer(forKey: R.DefaultKey.SystemCoreBuildVersion)
                let appBuildVersion = Int(R.Config.AppBuildVersion)!
                if appBuildVersion > systemCoreBuildVersion {
                    //build number增加，也需要进行资源刷新
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Resource))
                    forceRefresh = true
                }
            }
        } else {
            //内容为空 则强制刷新
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Resource))
            forceRefresh = true
        }
//#if DEBUG
//        forceRefresh = true
//#endif
        
        if forceRefresh || !FileManager.default.fileExists(atPath: R.Path.Resource) || !FileManager.default.fileExists(atPath: R.Path.ExtrasDB) {
            //将3DS的文件从Library移到Document 暴露给用户使用
            if FileManager.default.fileExists(atPath: R.Path.Library.appendingPathComponent("3DS")),
               !FileManager.default.fileExists(atPath: R.Path.ThreeDS) {
                try? FileManager.safeMoveItem(at: URL(fileURLWithPath: R.Path.Library.appendingPathComponent("3DS")), to: URL(fileURLWithPath: R.Path.ThreeDS))
            }
            //重新将Documents/Datas/3DS/sdmc 转移回 Documents/3DS/sdmc
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.ThreeDS.appendingPathComponent("sdmc_location.txt")))
            if !FileManager.default.fileExists(atPath: R.Path.ThreeDS.appendingPathComponent("sdmc")) {
                if FileManager.default.fileExists(atPath: R.Path.Data.appendingPathComponent("3DS/sdmc")) {
                    try? FileManager.safeMoveItem(at: URL(fileURLWithPath: R.Path.Data.appendingPathComponent("3DS/sdmc")),
                                                  to: URL(fileURLWithPath: R.Path.ThreeDS.appendingPathComponent("sdmc")),
                                                  shouldReplace: true)
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Data.appendingPathComponent("3DS")))
                } else {
                    try? FileManager.default.createDirectory(atPath: R.Path.ThreeDS.appendingPathComponent("sdmc"),
                                                             withIntermediateDirectories: true)
                }
            }
            
            let resourceUrl = Bundle.main.url(forResource: "System", withExtension: "core")!
            Log.debug("开始解压资源:\(Date.now.timeIntervalSince1970ms)")
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Resource))
            SSZipArchive.unzipFile(atPath: resourceUrl.path, toDestination: R.Path.Resource, overwrite: true, password: nil, progressHandler: nil) { _, isSuccess, error in
                
                //处理复用皮肤
                let reuseCores = System.allCores.filter({ $0.gameType.reuseGameType() != $0.gameType })
                for reuse in reuseCores {
                    let templateStandardSkinPath = R.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName).manicskin")
                    let newStandardSkinPath = R.Path.Resource.appendingPathComponent("\(reuse.name).manicskin")
                    do {
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateStandardSkinPath), to: URL(fileURLWithPath: newStandardSkinPath), shouldReplace: true)
                        let archive = try Archive(url: URL(fileURLWithPath: newStandardSkinPath), accessMode: .update)
                        if let oldInfoJson = archive["info.json"] {
                            try archive.remove(oldInfoJson)
                        }
                        try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("\(reuse.name).skininfo")))
                    } catch {
                        Log.debug("复用皮肤出错:\(error)")
                    }
                    
                    let templateFlexSkinPath = R.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName)_FLEX.manicskin")
                    let newFlexSkinPath = R.Path.Resource.appendingPathComponent("\(reuse.name)_FLEX.manicskin")
                    do {
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateFlexSkinPath), to: URL(fileURLWithPath: newFlexSkinPath), shouldReplace: true)
                        let archive = try Archive(url: URL(fileURLWithPath: newFlexSkinPath), accessMode: .update)
                        if let oldInfoJson = archive["info.json"] {
                            try archive.remove(oldInfoJson)
                        }
                        try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("\(reuse.name)_FLEX.skininfo")))
                    } catch {
                        Log.debug("复用皮肤出错:\(error)")
                    }
                    
                    let templateKeyboardSkinPath = R.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName)_KEYBOARD.manicskin")
                    let newKeyboardSkinPath = R.Path.Resource.appendingPathComponent("\(reuse.name)_KEYBOARD.manicskin")
                    let keyboardSkinInfoPath = R.Path.Resource.appendingPathComponent("\(reuse.name)_KEYBOARD.skininfo")
                    if FileManager.default.fileExists(atPath: templateKeyboardSkinPath),
                       FileManager.default.fileExists(atPath: keyboardSkinInfoPath) {
                        do {
                            try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateKeyboardSkinPath), to: URL(fileURLWithPath: newKeyboardSkinPath), shouldReplace: true)
                            let archive = try Archive(url: URL(fileURLWithPath: newKeyboardSkinPath), accessMode: .update)
                            if let oldInfoJson = archive["info.json"] {
                                try archive.remove(oldInfoJson)
                            }
                            try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: keyboardSkinInfoPath))
                        } catch {
                            Log.debug("复用皮肤出错:\(error)")
                        }
                    }
                }
                
                //生成EMPTY皮肤(需要读上面生成好的复用皮肤, 并且要在Database.addEmbedSkins之前完成)
                if isSuccess {
                    DispatchQueue.global().sync {
                        generateEmptySkins()
                    }
                }

                Log.debug("资源解压结束:\(Date.now.timeIntervalSince1970ms)")
                completion?(isSuccess)
                if isSuccess {
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("aes_keys.txt")), to: URL(fileURLWithPath: R.Path.ThreeDSSystemData.appendingPathComponent("aes_keys.txt")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("seeddb.bin")), to: URL(fileURLWithPath: R.Path.ThreeDSSystemData.appendingPathComponent("seeddb.bin")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("shared_font.bin")), to: URL(fileURLWithPath: R.Path.ThreeDSSystemData.appendingPathComponent("shared_font.bin")), shouldReplace: true)
                    
                    //Libretro的资源复制到对应位置
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Libretro/info")), to: URL(fileURLWithPath: R.Path.Libretro.appendingPathComponent("info")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Libretro/autoconfig")), to: URL(fileURLWithPath: R.Path.Libretro.appendingPathComponent("autoconfig")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Libretro/shaders/default")), to: URL(fileURLWithPath: R.Path.ShaderDefault), shouldReplace: true)
                    try? FileManager.safeReplaceDirectory(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Libretro/system")), to: URL(fileURLWithPath: R.Path.System))
                    try? FileManager.safeReplaceDirectory(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Libretro/config")), to: URL(fileURLWithPath: R.Path.Libretro.appendingPathComponent("config")))
                    if !FileManager.default.fileExists(atPath: R.Path.AzaharConfig) {
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.AzaharDefaultConfig), to: URL(fileURLWithPath: R.Path.AzaharConfig))
                    }
                    
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.CitraDefaultConfig), to: URL(fileURLWithPath: R.Path.CitraConfig), shouldReplace: true)
                    
                    if let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) {
                        let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
                        if systemCoreVersionNumber < 153 {
                            //适配PKSM 将存档位置进行调整
                            if let contents = try? FileManager.default.contentsOfDirectory(atPath: R.Path.Data) {
                                for content in contents {
                                    var newSaveUrl: URL? = nil
                                    if content.hasSuffix(".dsv") {
                                        //将dsv后缀改为srm
                                        newSaveUrl = URL(fileURLWithPath: R.Path.DSSavePath.appendingPathComponent("\(content.deletingPathExtension).srm"))
                                    } else if content.hasSuffix(".gba.sav") {
                                        //将.gba.sav 改成 .sav
                                        newSaveUrl = URL(fileURLWithPath: R.Path.GBASavePath.appendingPathComponent("\(content.replacingOccurrences(of: ".gba.sav", with: ".sav"))"))
                                    } else if content.hasSuffix(".gb.sav") {
                                        //将.gb.sav 改成 .sav
                                        //GB和GBC 都使用了.gb.sav的后缀格式，在这里需要将他们区分开
                                        let gameFileName = content.deletingPathExtension
                                        var isGBC = true
                                        if FileManager.default.fileExists(atPath: R.Path.Data.appendingPathComponent(gameFileName)), gameFileName.pathExtension.lowercased() == "gb" {
                                            isGBC = false
                                        }
                                        if isGBC {
                                            newSaveUrl = URL(fileURLWithPath: R.Path.GBCSavePath.appendingPathComponent("\(content.replacingOccurrences(of: ".gb.sav", with: ".sav"))"))
                                        } else {
                                            newSaveUrl = URL(fileURLWithPath: R.Path.GBSavePath.appendingPathComponent("\(content.replacingOccurrences(of: ".gb.sav", with: ".sav"))"))
                                        }
                                    }
                                    if let newSaveUrl {
                                        try? FileManager.safeMoveItem(at: URL(fileURLWithPath: R.Path.Data.appendingPathComponent(content)), to: newSaveUrl, shouldReplace: true)
                                    }
                                }
                            }
                        }
                        if systemCoreVersionNumber < 181 {
                            if let contents = try? FileManager.default.contentsOfDirectory(atPath: R.Path.Shaders) {
                                for content in contents {
                                    if content != "default" {
                                        try? FileManager.default.removeItem(atPath: R.Path.Shaders.appendingPathComponent(content))
                                    }
                                }
                            }
                        }
                        //升级1.8.3将DeSmuME核心的dsv存档全转转换为srm
                        if systemCoreVersionNumber < 183 {
                            if let contents = try? FileManager.default.contentsOfDirectory(atPath: R.Path.DSSavePath) {
                                for content in contents {
                                    if content.pathExtension.lowercased() == "dsv" {
                                        let contentUrl = URL(fileURLWithPath: R.Path.DSSavePath.appendingPathComponent(content))
                                        let newContentUrl = URL(fileURLWithPath: R.Path.DSSavePath.appendingPathComponent(content.deletingPathExtension + ".srm"))
                                        if FileManager.default.fileExists(atPath: newContentUrl.path) {
                                            continue
                                        } else {
                                            try? FileManager.safeMoveItem(at: contentUrl, to: newContentUrl)
                                        }
                                    }
                                }
                            }
                        }
                        
                        //remove GameList Background
                        if systemCoreVersionNumber < 200 {
                            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Assets.appendingPathComponent("iphone_background.png")))
                            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Assets.appendingPathComponent("ipad_background.png")))
                        }
                        
                        //update psp fonts
                        if systemCoreVersionNumber < 201 {
                            try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Libretro/system/PPSSPP/flash0/font/jpn0.pgf")),
                                                          to: URL(fileURLWithPath: R.Path.Document.appendingPathComponent("PPSSPP/PSP/NAND/flash0/font/jpn0.pgf")),
                                                          shouldReplace: true)
                        }
                    }
                    
                    Log.info("资源解压成功!")
                    UserDefaults.standard.set(R.Config.AppVersion, forKey: R.DefaultKey.SystemCoreVersion)
                    UserDefaults.standard.set(R.Config.AppBuildVersion, forKey: R.DefaultKey.SystemCoreBuildVersion)
                } else {
                    if let error = error {
                        Log.error("资源解压失败! error:\(error)")
                    } else {
                        Log.error("资源解压失败!")
                    }
                }
            }
        } else {
            completion?(true)
        }
    }

    //MARK: - EMPTY皮肤
    ///生成每个平台的EMPTY皮肤: 去掉所有控制按键, 只保留menu(以及DS/3DS的触屏项), 背景纯黑, 供TriggerPro使用。
    ///和复用皮肤一样在解压资源时生成, 这样不必把几十个二进制的manicskin提交到仓库。
    private static func generateEmptySkins() {
        let fileManager = FileManager.default
        let resourcePath = R.Path.Resource
        let backgroundName = "EMPTY_Background.pdf"
        let backgroundURL = URL(fileURLWithPath: resourcePath.appendingPathComponent(backgroundName))
        guard fileManager.fileExists(atPath: backgroundURL.path) else {
            Log.debug("[Skin] EMPTY: 缺少\(backgroundName), 跳过生成")
            return
        }
        ///固定时间戳, 让每次生成出来的皮肤文件字节一致(Skin.id是文件hash)
        let fixedDate = Date(timeIntervalSince1970: 315532800)
        let keepInputs: Set<String> = ["menu", "touchScreenX", "touchScreenY"]
        let tempDirectory = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent("EmptySkins"))
        try? FileManager.safeRemoveItem(at: tempDirectory)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.safeRemoveItem(at: tempDirectory) }

        var generatedCount = 0
        for core in System.allCores {
            let coreName = core.name
            let baseURL = URL(fileURLWithPath: resourcePath.appendingPathComponent("\(coreName).manicskin"))
            let destURL = URL(fileURLWithPath: resourcePath.appendingPathComponent("\(coreName)_EMPTY.manicskin"))
            guard fileManager.fileExists(atPath: baseURL.path) else {
                Log.debug("[Skin] EMPTY: 缺少\(coreName).manicskin, 跳过")
                continue
            }

            do {
                guard let baseArchive = try? Archive(url: baseURL, accessMode: .read, pathEncoding: nil),
                      let infoEntry = baseArchive["info.json"] else {
                    Log.debug("[Skin] EMPTY: 无法读取\(coreName).manicskin")
                    continue
                }
                var infoData = Data()
                try _ = baseArchive.extract(infoEntry) { infoData.append($0) }
                guard var info = try JSONSerialization.jsonObject(with: infoData) as? [String: Any],
                      let gameTypeIdentifier = info["gameTypeIdentifier"] as? String,
                      let oldName = info["name"] as? String,
                      let representations = info["representations"] else {
                    Log.debug("[Skin] EMPTY: \(coreName)的info.json格式不正确")
                    continue
                }

                info["identifier"] = gameTypeIdentifier + ".empty"
                info["name"] = oldName.contains("Standard") ? oldName.replacingOccurrences(of: "Standard", with: "EMPTY") : oldName + " EMPTY"
                info["debug"] = false
                var assetNames = Set<String>()
                info["representations"] = rewriteRepresentations(representations,
                                                                 keepInputs: keepInputs,
                                                                 backgroundName: backgroundName,
                                                                 assetNames: &assetNames,
                                                                 coreName: coreName)

                //把新的info.json、黑色背景和保留下来的素材放进临时目录
                let skinTempDirectory = tempDirectory.appendingPathComponent(coreName)
                try fileManager.createDirectory(at: skinTempDirectory, withIntermediateDirectories: true)
                try JSONSerialization.data(withJSONObject: info, options: [.sortedKeys])
                    .write(to: skinTempDirectory.appendingPathComponent("info.json"))
                try fileManager.copyItem(at: backgroundURL, to: skinTempDirectory.appendingPathComponent(backgroundName))
                //排序保证写入顺序稳定, 生成的皮肤文件才是字节一致的
                for assetName in assetNames.sorted() {
                    guard let assetEntry = baseArchive[assetName] else {
                        Log.debug("[Skin] EMPTY: \(coreName)缺少素材\(assetName)")
                        continue
                    }
                    var assetData = Data()
                    try _ = baseArchive.extract(assetEntry) { assetData.append($0) }
                    try assetData.write(to: skinTempDirectory.appendingPathComponent(assetName))
                }

                //打包成新的manicskin
                let files = try fileManager.contentsOfDirectory(at: skinTempDirectory, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
                for file in files {
                    try? fileManager.setAttributes([.modificationDate: fixedDate], ofItemAtPath: file.path)
                }
                try? FileManager.safeRemoveItem(at: destURL)
                do {
                    let archive = try Archive(url: destURL, accessMode: .create)
                    for file in files {
                        try archive.addEntry(with: file.lastPathComponent, fileURL: file)
                    }
                }
                generatedCount += 1
            } catch {
                Log.error("[Skin] EMPTY: 生成\(coreName)失败 \(error)")
            }
        }
        Log.debug("[Skin] EMPTY: 共生成\(generatedCount)套皮肤")
    }

    ///递归改写representations: 只保留menu和触屏项, 背景换成纯黑素材
    private static func rewriteRepresentations(_ node: Any,
                                               keepInputs: Set<String>,
                                               backgroundName: String,
                                               assetNames: inout Set<String>,
                                               coreName: String) -> Any {
        guard var dictionary = node as? [String: Any] else { return node }
        if dictionary["mappingSize"] != nil || dictionary["screens"] != nil || dictionary["items"] != nil {
            let items = dictionary["items"] as? [[String: Any]] ?? []
            var keptItems = items.filter({ item in
                inputValues(item["inputs"]).contains(where: { keepInputs.contains($0) })
            })
            //menu是触屏设备打开游戏内菜单的唯一入口, 没有menu项就保留原始按键, 不能生成不可用的皮肤
            if !keptItems.contains(where: { inputValues($0["inputs"]).contains("menu") }) {
                Log.error("[Skin] EMPTY: \(coreName)有representation未找到menu项, 保留原始按键")
                keptItems = items
            }
            for item in keptItems {
                guard let asset = item["asset"] as? [String: Any] else { continue }
                for case let name as String in asset.values where !name.isEmpty {
                    assetNames.insert(name)
                }
            }
            dictionary["items"] = keptItems
            dictionary["assets"] = ["resizable": backgroundName]
            return dictionary
        }
        var newDictionary = dictionary
        for (key, value) in dictionary {
            newDictionary[key] = rewriteRepresentations(value,
                                                        keepInputs: keepInputs,
                                                        backgroundName: backgroundName,
                                                        assetNames: &assetNames,
                                                        coreName: coreName)
        }
        return newDictionary
    }

    ///skins里inputs有字符串、数组、字典三种写法, 统一取值来判断
    private static func inputValues(_ inputs: Any?) -> [String] {
        if let value = inputs as? String { return [value] }
        if let values = inputs as? [String] { return values }
        if let values = inputs as? [String: String] { return Array(values.values) }
        return []
    }
}
