//
// ChannelViewController.swift
//
// BeagleIM
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

class ChannelViewController: AbstractChatViewControllerWithSharing, NSTableViewDelegate, ConversationLogContextMenuDelegate {

    @IBOutlet var channelAvatarView: AvatarViewWithStatus!
    @IBOutlet var channelNameLabel: NSTextFieldCell!
    @IBOutlet var channelJidLabel: NSTextFieldCell!
    @IBOutlet var channelDescriptionLabel: NSTextFieldCell!;

    @IBOutlet var infoButton: NSButton!;
    @IBOutlet var participantsButton: NSButton!;
    @IBOutlet var actionsButton: NSPopUpButton!;

    private var keywords: [String]? = Settings.markKeywords.stringArrays();

    var channel: DBChatStore.DBChannel! {
        return self.chat as? DBChatStore.DBChannel;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        let cgRef = infoButton.image!.cgImage(forProposedRect: nil, context: nil, hints: nil);
        let representation = NSBitmapImageRep(cgImage: cgRef!);
        let newRep = representation.converting(to: .genericGray, renderingIntent: .default);
        infoButton.image = NSImage(cgImage: newRep!.cgImage!, size: infoButton.frame.size);
        buttonToGrayscale(button: infoButton, template: false);
        buttonToGrayscale(button: participantsButton, template: true);
    }
    
    override func viewWillAppear() {
        channelNameLabel.title = channel.name ?? channel.channelJid.stringValue;
        channelJidLabel.title = jid.stringValue;
        
        channelAvatarView.backgroundColor = NSColor(named: "chatBackgroundColor")!;
        channelAvatarView.name = channel.name ?? jid.stringValue;
        channelAvatarView.update(for: jid, on: account);
        channelAvatarView.status = (XmppService.instance.getClient(for: channel.account)?.state ?? .disconnected == .connected) && channel.state == .joined ? .online : nil;
        channelDescriptionLabel.title = channel.description ?? "";

        NotificationCenter.default.addObserver(self, selector: #selector(participantsChanged(_:)), name: MixEventHandler.PARTICIPANTS_CHANGED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(channelUpdated(_:)), name: DBChatStore.CHAT_UPDATED, object: channel);
        NotificationCenter.default.addObserver(self, selector: #selector(avatarChanged(_:)), name: AvatarManager.AVATAR_CHANGED, object: nil);
        
        self.participantsButton.title = "\(channel.participants.count)";
        
        super.viewWillAppear();
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear();
        NotificationCenter.default.removeObserver(self, name: MixEventHandler.PARTICIPANTS_CHANGED, object: nil);
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let item = dataSource.getItem(at: row) else {
            return nil;
        }
        
        let prevItem = row >= 0 && (row + 1) < dataSource.count ? dataSource.getItem(at: row + 1) : nil;
        let continuation = prevItem != nil && item.isMergeable(with: prevItem!);

        switch item {
        case let item as SystemMessage:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ChatMessageSystemCellView"), owner: nil) as? ChatMessageSystemCellView {
                cell.message.stringValue = "Unread messages";
                return cell;
            }
            return nil;
        case let item as ChatMessage:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: continuation ? "ChatMessageContinuationCellView" : "ChatMessageCellView"), owner: nil) as? BaseChatMessageCellView {

                cell.id = item.id;
                if let c = cell as? ChatMessageCellView {
                    if let senderJid = item.state.direction == .incoming ? item.authorJid : item.account {
                        c.set(avatar: AvatarManager.instance.avatar(for: senderJid, on: item.account));
//                    } else if let nickname = item.authorNickname, let photoHash = self.room.presences[nickname]?.presence.vcardTempPhoto {
//                        c.set(avatar: AvatarManager.instance.avatar(withHash: photoHash));
                    } else {
                        c.set(avatar: nil);
                    }
                    
                    c.set(senderName: item.authorNickname ?? "Unknown");
                }
                cell.set(message: item, nickname: channel.nickname, keywords: keywords);

                return cell;
            }
            return nil;
        case let item as ChatLinkPreview:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ChatLinkPreviewCellView"), owner: nil) as? ChatLinkPreviewCellView {
                cell.set(item: item);
                return cell;
            }
            return nil;
        case let item as ChatAttachment:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: continuation ? "ChatAttachmentContinuationCellView" : "ChatAttachmentCellView"), owner: nil) as? BaseChatAttachmentCellView {
                if let c = cell as? ChatAttachmentCellView {
                    if let senderJid = item.state.direction == .incoming ? item.authorJid : item.account {
                        c.set(avatar: AvatarManager.instance.avatar(for: senderJid, on: item.account));
//                    } else if let nickname = item.authorNickname, let photoHash = self.room.presences[nickname]?.presence.vcardTempPhoto {
//                        c.set(avatar: AvatarManager.instance.avatar(withHash: photoHash));
                    } else {
                        c.set(avatar: nil);
                    }
                                    
                    c.set(senderName: item.authorNickname ?? "Unknown");
                }
                cell.set(item: item);
                return cell;
            }
            return nil;
        default:
            return nil;
        }
    }
    
    override func conversationTableViewDelegate() -> NSTableViewDelegate? {
        return self;
    }

    func prepareConversationLogContextMenu(dataSource: ChatViewDataSource, menu: NSMenu, forRow row: Int) {
        
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let channelAware = segue.destinationController as? ChannelAwareProtocol {
            channelAware.channel = self.channel;
        }
    }

    override func send(message: String) -> Bool {
        guard let client = XmppService.instance.getClient(for: account), client.state == .connected, channel.state == .joined else {
            return false;
        }
        let msg = channel.createMessage(message);
        client.context.writer?.write(msg);
        return true;
    }
    
    @objc func avatarChanged(_ notification: Notification) {
        guard let account = notification.userInfo?["account"] as? BareJID, let jid = notification.userInfo?["jid"] as? BareJID else {
            return;
        }
        DispatchQueue.main.async {
            guard self.channel.account == account && self.channel.channelJid == jid else {
                return;
            }
            self.channelAvatarView.avatar = AvatarManager.instance.avatar(for: self.channel.channelJid, on: self.channel.account);
        }
    }

    @objc func channelUpdated(_ notification: Notification) {
        guard let channel = notification.object as? Channel else {
            return;
        }
        DispatchQueue.main.async {
            self.channelAvatarView.name = self.channel.name ?? self.channel.channelJid.stringValue;
            self.channelAvatarView.status = (XmppService.instance.getClient(for: self.channel.account)?.state ?? .disconnected == .connected) && self.channel.state == .joined ? .online : nil;
            self.channelNameLabel.title = self.channel.name ?? self.channel.channelJid.stringValue;
            self.channelDescriptionLabel.title = self.channel.description ?? "";
        }
    }
    
    @objc func participantsChanged(_ notification: Notification) {
        guard let e = notification.object as? MixModule.ParticipantsChangedEvent else {
            return;
        }
        DispatchQueue.main.async {
            guard self.channel.id == (e.channel as? DBChatStore.DBChannel)?.id else {
                return;
            }
            self.participantsButton.title = "\(self.channel.participants.count)";
        }
    }
        
    @IBAction func showInfoClicked(_ sender: NSButton) {
        let storyboard = NSStoryboard(name: "ConversationDetails", bundle: nil);
        guard let viewController = storyboard.instantiateController(withIdentifier: "ContactDetailsViewController") as? ContactDetailsViewController else {
            return;
        }
        viewController.account = self.account;
        viewController.jid = self.jid;
        viewController.viewType = .chat;

        let popover = NSPopover();
        popover.contentViewController = viewController;
        popover.behavior = .semitransient;
        popover.animates = true;
        let rect = sender.convert(sender.bounds, to: self.view.window!.contentView!);
        popover.show(relativeTo: rect, of: self.view.window!.contentView!, preferredEdge: .minY);
    }
    
    @IBAction func showEditChannelHeader(_ sender: NSMenuItem) {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier("ShowEditChannelHeaderSheet"), sender: self);
    }

    private func buttonToGrayscale(button: NSButton, template: Bool) {
        let cgRef = button.image!.cgImage(forProposedRect: nil, context: nil, hints: nil);
        let representation = NSBitmapImageRep(cgImage: cgRef!);
        let newRep = representation.converting(to: .genericGray, renderingIntent: .default);
        let img = NSImage(cgImage: newRep!.cgImage!, size: NSSize(width: button.frame.size.height, height: button.frame.size.height));
        img.isTemplate = template;
        button.image = img;
    }

}
