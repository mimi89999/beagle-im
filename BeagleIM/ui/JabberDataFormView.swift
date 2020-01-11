//
// JabberDataFormView.swift
//
// BeagleIM
// Copyright (C) 2018 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see https://www.gnu.org/licenses/.
//

import AppKit
import TigaseSwift

class JabberDataFormView: NSTableView, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBInspectable var labelsToRight: Bool = false;
    
    fileprivate var visibleFields: [String] = [];
    fileprivate var namedFieldViews: [String: Any] = [:];
        
    override var isHidden: Bool {
        didSet {
            updateHeight();
        }
    }
    
    fileprivate(set) var estimatedHeight: CGFloat = 0.0 {
        didSet {
            updateHeight();
        }
    }
    
    func updateHeight() {
        let oldConstraint = heightConstraint;
        heightConstraint = self.enclosingScrollView?.heightAnchor.constraint(equalToConstant: isHidden ? 0.0 : min(estimatedHeight + 10, 600));
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = 0.25;
            context.allowsImplicitAnimation = true;
            oldConstraint?.animator().isActive = false;
            heightConstraint?.animator().isActive = true;
        }, completionHandler: {
            if oldConstraint != nil {
                self.enclosingScrollView?.removeConstraint(oldConstraint!);
            }
            print("document height:", self.enclosingScrollView?.documentView?.frame.size.height, self.enclosingScrollView?.contentSize);
        });
    }
    
    var hideFields: [String] = [];
    var instruction: String?;
    
    var form: JabberDataElement? {
        didSet {
            visibleFields = form?.visibleFieldNames.filter({ name -> Bool in !self.hideFields.contains(name)}) ?? [];
            
            self.instruction = form?.instructions.map({ (texts) -> String in
                return texts.filter({ $0 != nil }).map({ $0! }).joined(separator: "\n");
                });
            if self.instruction?.isEmpty ?? false {
                self.instruction = nil;
            }
            self.reloadData();

            var estHeight = self.numberOfRows == 0 ? 0 : self.rect(ofColumn: 0).height;
            if self.numberOfRows < 20 {
                estHeight = 0;
                let offset = self.instruction != nil ? 1 : 0;
                for i in 0..<self.numberOfRows {
                    
                    let label = i == 0 && self.instruction != nil ? self.instruction! : self.extractLabel(from: form!.getField(named: visibleFields[i - offset])!);
                    
                    let textStorage = NSTextStorage(string: label);
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.labelFontSize, weight: i == 0 && self.instruction != nil ? .medium : .regular), range: NSRange(0..<textStorage.length));
                    let layoutManager = NSLayoutManager()
                    let containerSize = CGSize(width: self.tableColumns[0].width - self.intercellSpacing.width,
                                               height: .greatestFiniteMagnitude);
                    let container = NSTextContainer(size: containerSize)
                    container.widthTracksTextView = true
                    layoutManager.addTextContainer(container)
                    textStorage.addLayoutManager(layoutManager)
                    layoutManager.glyphRange(for: container);
                    let c1Size = layoutManager.usedRect(for: container).size;
                    
                    let c2 = self.tableView(self, viewFor: self.tableColumns[1], row: i);
                    let c2Size = c2?.fittingSize;

                    estHeight += max(c1Size.height + 4, (c2Size?.height ?? 0.0) + 4);
                }
            }
            estimatedHeight = estHeight;
        }
    }
    
    var heightConstraint: NSLayoutConstraint?;
    
    override func viewDidMoveToSuperview() {
        self.updateHeight();
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect);
        self.delegate = self;
        self.dataSource = self;
        self.intercellSpacing = NSSize(width: 3, height: 8);
        self.translatesAutoresizingMaskIntoConstraints = false;
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self;
        self.dataSource = self;
        self.intercellSpacing = NSSize(width: 3, height: 8);
        self.translatesAutoresizingMaskIntoConstraints = false;
    }
    
    func synchronize() {
        self.window?.makeFirstResponder(nil);
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return visibleFields.count + (self.instruction == nil ? 0 : 1);
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return row == 0 && self.instruction != nil;
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard row != 0 || self.instruction == nil else {
            return NSTableInstructionsRowView(frame: .zero);
        }
        return tableView.rowView(atRow: row, makeIfNecessary: true);
    }
        
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard !self.tableView(tableView, isGroupRow: row) else {
            let horizontalSpacing = self.intercellSpacing.width / 2;
            let view = NSTextField(labelWithString: self.instruction ?? "");
            view.alignment = .justified;
            view.lineBreakMode = .byWordWrapping;
            view.cell?.lineBreakMode = .byWordWrapping;
            view.isEditable = false;
            view.isSelectable = false;
            view.translatesAutoresizingMaskIntoConstraints = false;
            view.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal);
            view.setContentHuggingPriority(.defaultLow, for: .horizontal);
            view.setContentHuggingPriority(.defaultLow, for: .vertical);
            view.setContentCompressionResistancePriority(.required, for: .vertical);
            view.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium);

            let cellView = NSTableInstructionsCellView(frame: .zero);
            cellView.addSubview(view);
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: horizontalSpacing),
                view.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -1 * horizontalSpacing),
                view.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 3.0),
                view.bottomAnchor.constraint(equalTo: cellView.bottomAnchor)]);

            cellView.backgroundStyle = .normal;
            
            return cellView;
        }
        let offset = self.instruction != nil ? 1 : 0;
        if tableColumn != nil {
            let horizontalSpacing = self.intercellSpacing.width / 2;
            let field = form?.getField(named: visibleFields[row - offset]);
            if tableView.column(withIdentifier: tableColumn!.identifier) == 0 {
                if field is BooleanField {
                    return nil;
                }
                let view = NSTextField(labelWithString: extractLabel(from: field!));
                view.alignment = labelsToRight ? .right : .left;
                view.lineBreakMode = .byWordWrapping;
                view.cell?.lineBreakMode = .byWordWrapping;
                view.isEditable = false;
                view.isSelectable = false;
                view.translatesAutoresizingMaskIntoConstraints = false;
                view.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal);
                view.setContentHuggingPriority(.defaultLow, for: .horizontal);
                view.setContentHuggingPriority(.defaultLow, for: .vertical);
                view.setContentCompressionResistancePriority(.required, for: .vertical);

                let cellView = NSTableCellView(frame: .zero);
                cellView.addSubview(view);
                NSLayoutConstraint.activate([
                    view.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: horizontalSpacing),
                    view.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -1 * horizontalSpacing),
                    view.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 3.0),
                    view.bottomAnchor.constraint(equalTo: cellView.bottomAnchor)]);

                return cellView;
            } else {
                let view = create(row: row - offset, field: field!);
                view.translatesAutoresizingMaskIntoConstraints = false;
                view.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal);
                view.setContentHuggingPriority(.fittingSizeCompression, for: .vertical);

                if view is NSTextView {
                    let cellView = NSTableCellViewForTextView(frame: .zero);
                    cellView.addSubview(view);
                    NSLayoutConstraint.activate([
                        view.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: horizontalSpacing),
                        view.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -1 * horizontalSpacing),
                        view.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 3.0),
                        view.bottomAnchor.constraint(lessThanOrEqualTo: cellView.bottomAnchor, constant: -3.0)]);
                    return cellView;
                } else {
                    let cellView = NSTableCellView(frame: .zero);
                    cellView.addSubview(view);
                    NSLayoutConstraint.activate([
                        view.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: horizontalSpacing),
                        view.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -1 * horizontalSpacing),
                        view.topAnchor.constraint(equalTo: cellView.topAnchor, constant: ((view as? NSTextField)?.isEditable ?? false) ? 0.0 : 3.0),
                        view.bottomAnchor.constraint(lessThanOrEqualTo: cellView.bottomAnchor)]);
                    return cellView;
                }
            }
       }
        return nil;
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false;
    }
    
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        return true;
    }
    
    fileprivate func extractLabel(from formField: Field) -> String {
        return formField.label ?? (formField.name.prefix(1).uppercased() + formField.name.dropFirst());
    }
    
    fileprivate func create(row: Int, field formField: Field) -> NSView {
        let label = formField.label ?? (formField.name.prefix(1).uppercased() + formField.name.dropFirst());
        switch formField {
        case let f as BooleanField:
            return addCheckbox(row: row, label: label, value: f.value);
        case let f as TextSingleField:
            return addTextField(row: row, label: label, value: f.value);
        case let f as TextPrivateField:
            return addTextPrivateField(row: row,label: label, value: f.value);
        case let f as TextMultiField:
            return addTextMultiField(row: row, label: label, value: f.value);
        case let f as JidSingleField:
            return addTextField(row: row, label: label, value: f.value?.stringValue);
        case let f as JidMultiField:
            return addTextMultiField(row: row, label: label, value: f.value.map({ j -> String in return j.stringValue}));
        case let f as ListSingleField:
            return addListSingleField(row: row, label: label, value: f.value, options: f.options);
        case let f as ListMultiField:
            return addListMultiField(row: row, label: label, value: f.value, options: f.options);
        case let f as FixedField:
            return addFixedField(label: label, value: f.value);
        default:
            return NSView(frame: .zero);
        }
    }
    
    fileprivate func addCheckbox(row: Int, label: String, value: Bool) -> NSButton {
        let tooltip = String(label.drop(while: { (ch) -> Bool in
            ch != "(";
        }));
        let field = NSButton(checkboxWithTitle: String(label.dropLast(tooltip.count)), target: self, action: #selector(fieldChanged(_:)));
        field.tag = row;
        if !tooltip.isEmpty {
            field.toolTip = tooltip;
        }
        field.state = value ? .on : .off;
        return field;
    }
    
    @objc fileprivate func fieldChanged(_ sender: NSView) {
        let row = (sender as? MultiSelectField)?.row ?? sender.tag;
        switch self.form?.getField(named: visibleFields[row])! {
        case let f as BooleanField:
            f.value = (sender as! NSButton).state == .on;
        case let f as TextSingleField:
            f.value = (sender as! NSTextField).stringValue;
        case let f as TextPrivateField:
            f.value = (sender as! NSTextField).stringValue;
        case let f as JidSingleField:
            let v = (sender as? NSTextField)?.stringValue.trimmingCharacters(in: .whitespaces);
            f.value = (v?.isEmpty ?? true) ? nil : JID(v!);
        case let f as ListMultiField:
            let v = (sender as! MultiSelectField).value;
            f.value = v;
        default:
            break;
        }
    }
    
    override func textDidChange(_ notification: Notification) {
        guard let sender = (notification.object as? MyTextView) else {
            return;
        }
        let row = sender.row;
        
        switch self.form?.getField(named: self.visibleFields[row])! {
        case let f as TextMultiField:
            let v = sender.string;
            f.value = v.split(separator: "\n").map({ s in String(s) });
        case let f as JidMultiField:
            let v = sender.string.split(separator: "\n");
            f.value = v.map({ s in String(s) }).map({ s in JID(s) });
        default:
            break;
        }
    }

    fileprivate func addFixedField(label: String, value: String?) -> NSTextField {
        let field = NSTextField(string: value ?? "");
        field.isEditable = false;
        field.isEnabled = false;
        return field;
    }
    
    fileprivate func addTextField(row: Int, label: String, value: String?) -> NSTextField {
        let field = NSTextField(string: value ?? "");
        field.setContentCompressionResistancePriority(.required, for: .vertical);
        field.isEditable = true;
        field.tag = row;
        field.target = self;
        field.action = #selector(fieldChanged(_:))
        return field;
    }

    fileprivate func addTextPrivateField(row: Int, label: String, value: String?) -> NSSecureTextField {
        let field = NSSecureTextField(string: value ?? "");
        field.isEditable = true;
        field.tag = row;
        field.target = self;
        field.action = #selector(fieldChanged(_:))
        return field;
    }

    fileprivate func addTextMultiField(row: Int, label: String, value: [String]) -> NSView {
//        let scroll = NSScrollView(frame: .zero);
//        scroll.autoresizingMask = [.width, .height];
//        scroll.hasHorizontalRuler = false;
//        scroll.heightAnchor.constraint(equalToConstant: 100);
        
//        let contentSize = scroll.contentSize;
        
        let field = MyTextView(frame: .zero);//NSRect(x: 0, y:0, width: contentSize.width, height: contentSize.height));
        field.row = row;
        field.minSize = NSSize(width: 0.0, height: 100);//contentSize.height);
        field.maxSize = NSSize(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude);
        field.isVerticallyResizable = true;
        field.isHorizontallyResizable = false;
        field.autoresizingMask = .width;
//        field.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat(Float.greatestFiniteMagnitude));
        field.string = value.joined(separator: "\n");
        field.textContainer?.widthTracksTextView = true;
        
        field.delegate = self;
        
//        scroll.documentView = field;
        
        return field;
    }
    
    fileprivate func addListSingleField(row: Int, label: String, value: String?, options: [ListFieldOption]) -> NSButton {
        let field = NSPopUpButton(frame: .zero, pullsDown: true);
        field.addItem(withTitle: "");
        field.action = #selector(listSelectionChanged);
        field.target = self;
        field.tag = row;
        field.addItems(withTitles: options.map { option in option.label ?? option.value });
        if let idx = options.firstIndex(where: { (option) -> Bool in
            return (value ?? "") == option.value;
        }) {
            field.selectItem(at: idx + 1);
            field.title = field.titleOfSelectedItem ?? "";
        }
        return field;
    }
    
    @objc fileprivate func listSelectionChanged(_ sender: NSPopUpButton) {
        sender.title = sender.titleOfSelectedItem ?? "";
        switch self.form?.getField(named: self.visibleFields[sender.tag])! {
        case let f as ListSingleField:
            let v = sender.indexOfSelectedItem;
            f.value = v == -1 ? nil : f.options[v-1].value;
        default:
            break;
        }
    }
    
    fileprivate func addListMultiField(row: Int, label: String, value: [String], options: [ListFieldOption]) -> NSStackView {
        let field = MultiSelectField(row: row, value: value, options: options);
        field.action = #selector(fieldChanged(_:))
        field.target = self;
        return field;
    }
 
    class MyTextView: NSTextView {
        var row: Int = 0;
        
        override var intrinsicContentSize: NSSize {
            self.layoutManager!.ensureLayout(for: self.textContainer!);
            let size = layoutManager!.usedRect(for: self.textContainer!).size;
            if size.height < 100 {
                return NSSize(width: size.width, height: 100);
            }
            return size;
        }
        
        override func didChangeText() {
            super.didChangeText();
            self.invalidateIntrinsicContentSize();
        }
        
    }

    class MultiSelectField: NSStackView {
        
        let row: Int;
        let options: [ListFieldOption];
        var value: [String];
        var action: Selector?;
        weak var target: NSObject?;
        
        init(row: Int, value: [String], options: [ListFieldOption]) {
            self.row = row;
            self.options = options;
            self.value = value;
            super.init(frame: .zero);
            self.alignment = .leading;
            self.orientation = .vertical;
            self.options.forEach { (option) in
                let field = NSButton(checkboxWithTitle: option.label ?? option.value, target: self, action: #selector(checkboxChanged));
                field.state = value.contains(option.value) ? .on : .off;
                self.addView(field, in: .bottom);
            }
        }
        
        required init?(coder decoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc fileprivate func checkboxChanged(_ sender: NSButton) {
            var newValue: [String] = [];
            self.subviews.enumerated().forEach { (arg0) in
                let (row, item) = arg0
                let button = item as! NSButton;
                if button.state == .on {
                    newValue.append(self.options[row].value);
                }
            }
            self.value = newValue;
            if action != nil {
                target?.performSelector(onMainThread: action!, with: self, waitUntilDone: true);
            }
        }
    }
    
    class NSTableCellViewForTextView: NSTableCellView {
        
        override func draw(_ dirtyRect: NSRect) {
            NSGraphicsContext.saveGraphicsState();
            NSColor.textBackgroundColor.setFill();
            self.bounds.fill();
            NSColor.controlShadowColor.set();
            self.bounds.frame();
            NSGraphicsContext.restoreGraphicsState();
        }
        
    }
    
    class NSTableInstructionsRowView: NSTableRowView {
        override func draw(_ dirtyRect: NSRect) {
        }
    }
    
    class NSTableInstructionsCellView: NSTableCellView {
        override var backgroundStyle: NSView.BackgroundStyle {
            get {
                return .normal;
            }
            set {
                // nothing to do..
            }
        }
        
        override func draw(_ dirtyRect: NSRect) {
            NSGraphicsContext.saveGraphicsState();
            NSColor.windowBackgroundColor.setFill();
            self.bounds.fill();
            NSGraphicsContext.restoreGraphicsState();

        }
    }
}
