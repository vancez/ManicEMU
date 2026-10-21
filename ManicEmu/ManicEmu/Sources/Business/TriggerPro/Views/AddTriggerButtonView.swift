//
//  AddTriggerButtonView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit
import RealmSwift
import BetterSegmentedControl
import IceCream

/// Captures the next digital button pressed on any connected MFi controller.
/// The editor temporarily uses the mapping input sink so controller mapping and
/// gameplay receivers ignore the capture input.
private final class TriggerProControllerBindingCapture: NSObject, GameControllerReceiver {
    private let completion: (String?) -> Void
    private var controllers: [GameController] = []
    private var previousSink: ExternalInputSink?
    private var isFinished = false

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
        super.init()
    }

    deinit {
        controllers.forEach { $0.removeReceiver(self) }
        if let previousSink {
            ExternalInputDispatch.sink = previousSink
        }
    }

    func start() -> Bool {
        let controllers = ExternalGameControllerManager.shared.connectedControllers.filter { $0.inputType == .mfi }
        guard !controllers.isEmpty else { return false }

        self.controllers = controllers
        self.previousSink = ExternalInputDispatch.sink
        ExternalInputDispatch.sink = .mapping
        controllers.forEach { $0.addReceiver(self, inputMapping: nil) }
        return true
    }

    func cancel() {
        finish(nil)
    }

    private func finish(_ input: String?) {
        guard !isFinished else { return }
        isFinished = true

        controllers.forEach { $0.removeReceiver(self) }
        controllers.removeAll()
        if let previousSink {
            ExternalInputDispatch.sink = previousSink
        }
        previousSink = nil

        let completion = self.completion
        DispatchQueue.main.async {
            completion(input)
        }
    }

    func gameController(_ gameController: any GameController, didActivate input: any Input, value: Double) {
        guard !isFinished, !input.isContinuous, value >= 0.5 else { return }
        finish(input.stringValue)
    }

    func gameController(_ gameController: any GameController, didDeactivate input: any Input) {}
}

class AddTriggerButtonView: BaseView {
    
    private lazy var buttonStyleView: AddTriggerButtonStyleView = {
        let view = AddTriggerButtonStyleView(item: triggerItem)
        view.needToUpdateCellHeight = { [weak self] in
            guard let self else { return }
            self.listPageView.sections = self.getSections()
        }
        return view
    }()
    
    private lazy var mappingListView: AddTriggerMappingListView = {
        let view = AddTriggerMappingListView(triggerItem: triggerItem)
        view.didTapAddMapping = { [weak self] updateViews in
            guard let self else { return }
            TriggerProMappingListView.show(inputs: self.inputs,
                                           gameType: self.gameType) { [weak self] input in
                guard let self else { return }
                self.triggerItem.mappings.append(input)
                updateViews?()
            }
        }
        return view
    }()
    
    private lazy var actionView: AddTriggerActionView = {
        let view = AddTriggerActionView(triggerItem: triggerItem)
        view.didActionChange = { [weak self ] in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self ] in
                guard let self else { return }
                self.listPageView.sections = self.getSections()
            }
        }
        return view
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(.init(navigation: .defaultNavigation(title: "TriggerPro",
                                                                       titleIcon: .symbolImage(R.image.triggerpro_iconSymbols())),
                                        sections: getSections(),
                                        backgroundColor: .clear,
                                        pageInsets: .insets(top: R.Size.SheetGrabberTopInset)))
        
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue {
                if navigationValue.isTapClose {
                    self.controllerBindingCapture?.cancel()
                    self.controllerBindingCapture = nil
                    if self.triggerItem.mappings.count == 0 {
                        UIView.makeAlert(title: R.string.localizable.fatalErrorTitle(),
                                         detail: R.string.localizable.noMappingAlert(),
                                         confirmTitle: R.string.localizable.multiDiscContinueClose(),
                                         confirmAction: { [weak self] in
                            self?.hide()
                        })
                        return
                    }
                    self.hide()
                }
            } else if let normalItemValue = action.normalItemValue {
                guard normalItemValue.indexPath.section == 3 else { return }
                if normalItemValue.indexPath.row == 0 {
                    self.startControllerBindingCapture()
                } else if normalItemValue.indexPath.row == 1 {
                    self.clearControllerBinding()
                }
            }
        }
        return view
    }()
    
    private var triggerItem: TriggerItem
    private let gameType: GameType
    private let inputs: [String]
    private let trigger: Trigger
    private var controllerBindingCapture: TriggerProControllerBindingCapture?
    var hideCompletion: (() -> Void)? = nil

    required init?(parameters: Any...) {
        guard let triggerItem = parameters.compactMap({ $0 as? TriggerItem }).first else { return nil }
        guard let gameType = parameters.compactMap({ $0 as? GameType }).first else { return nil }
        guard let inputs = parameters.compactMap({ $0 as? [String] }).first else { return nil }
        guard let trigger = parameters.compactMap({ $0 as? Trigger }).first else { return nil }
        self.triggerItem = triggerItem
        self.gameType = gameType
        self.inputs = inputs
        self.trigger = trigger
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getSections() -> [ASListPage.Section] {
        var sections = [ASListPage.Section]()
        sections.append(.init(cells: [.custom(buttonStyleView)],
                              header: .defaultHeader(title: R.string.localizable.buttonStyle()),
                              itemLayout: .fixedHeight(triggerItem.style.cellHeight)))
        sections.append(.init(cells: [.custom(mappingListView)],
                              header: .defaultHeader(title: R.string.localizable.mapping()),
                              itemLayout: .fixedHeight(72)))
        sections.append(.init(cells: [.custom(actionView)],
                              header: .texts([
                                .init(attributes: .init(text: R.string.localizable.action(),
                                                        color: R.Color.LabelSecondary,
                                                        font: R.Font.Subheadline(emphasis: true))),
                                .init(attributes: .init(text: triggerItem.action.desc,
                                                        color: R.Color.LabelSecondary,
                                                        font: R.Font.Footnote(),
                                                        numberOfLines: 0),
                                      textIcons: [.init(icon: .symbolImage(R.image.infoFill_iconSymbols()),
                                                        iconSize: 14)])
                              ], pin: false),
                              itemLayout: .fixedHeight(216)))

        let boundInput = trigger.controllerInput(for: triggerItem.id)
        var bindingCells: [ASListPage.Cell] = [
            .iconTitleChevronCell(title: boundInput.map({ self.controllerInputDisplayName($0) }) ?? R.string.localizable.controllerButtonUnbound())
        ]
        if boundInput != nil {
            bindingCells.append(.iconTitleChevronCell(title: R.string.localizable.controllerButtonClear(),
                                                      titleColor: R.Color.Red))
        }
        sections.append(.init(cells: bindingCells,
                              header: .defaultHeader(title: R.string.localizable.controllerButton())))
        return sections
    }

    private func startControllerBindingCapture() {
        guard controllerBindingCapture == nil else { return }
        guard ExternalGameControllerManager.shared.connectedControllers.contains(where: { $0.inputType == .mfi }) else {
            UIView.makeToast(message: R.string.localizable.controllerButtonConnectFirst())
            return
        }

        let capture = TriggerProControllerBindingCapture { [weak self] input in
            guard let self else { return }
            self.controllerBindingCapture = nil
            if let input {
                UIView.hideAlert()
                self.applyControllerInput(input)
            }
        }
        controllerBindingCapture = capture

        UIView.makeAlert(identifier: "TriggerProControllerBinding",
                         title: R.string.localizable.controllerButton(),
                         detail: R.string.localizable.controllerButtonPrompt(),
                         cancelTitle: R.string.localizable.cancelTitle(),
                         cancelAction: { [weak self] in
                             self?.controllerBindingCapture?.cancel()
                         },
                         hideAction: { [weak self] _ in
                             self?.controllerBindingCapture?.cancel()
                         })

        if !capture.start() {
            controllerBindingCapture = nil
            UIView.hideAlert()
            UIView.makeToast(message: R.string.localizable.controllerButtonConnectFirst())
        }
    }

    private func clearControllerBinding() {
        trigger.setControllerInput(nil, for: triggerItem.id)
        listPageView.sections = getSections()
    }

    private func applyControllerInput(_ input: String) {
        guard !trigger.hasControllerBindingConflict(input: input, excluding: triggerItem.id) else {
            UIView.makeToast(message: R.string.localizable.controllerButtonDuplicate())
            return
        }
        trigger.setControllerInput(input, for: triggerItem.id)
        listPageView.sections = getSections()
    }

    private func controllerInputDisplayName(_ input: String) -> String {
        switch input {
        case "leftShoulder": return "L1"
        case "rightShoulder": return "R1"
        case "leftTrigger": return "L2"
        case "rightTrigger": return "R2"
        case "leftThumbstickButton": return "L3"
        case "rightThumbstickButton": return "R3"
        case "menu": return "Menu"
        case "start": return "Start"
        case "select": return "Select"
        case "up": return "Up"
        case "down": return "Down"
        case "left": return "Left"
        case "right": return "Right"
        default: return input.uppercased()
        }
    }
}

extension AddTriggerButtonView: ShowableView {
    static func show(triggerItem: TriggerItem, gameType: GameType, inputs: [String], trigger: Trigger, hideCompletion: (() -> Void)? = nil) {
        Self.show(parameters: triggerItem, gameType, inputs, trigger)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        hideCompletion?()
    }
}
