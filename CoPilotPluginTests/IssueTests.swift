//
//  IssueTests.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 14/05/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Cocoa
import XCTest
import Nimble


class IssueTests: XCTestCase {

    var server: DocServer!


    override func tearDown() {
        self.server?.stop()
    }


    // https://bitbucket.org/feinstruktur/copilot/issue/7/crash-when-cursor-at-end-and-receiving-an
    func test_issue_7() {
        let tv = NSTextView()
        let a = "123"
        let newDoc = Document("0123")
        tv.string = a
        expect(count(tv.string!)) == 3
        tv.setSelectedRange(NSRange(location: 3, length: 0))
        
        let patches = computePatches(tv.string, newDoc.text)
        let selected = tv.selectedRange
        let currentPos = Position(selected.location)
        let newPos = newPosition(currentPos, patches)
        
        tv.textStorage?.replaceAll(newDoc.text)
        
        let newSelection = adjustSelection(selected, newPos, newDoc.text)
        tv.setSelectedRange(newSelection)
    }
    
    
    // https://bitbucket.org/feinstruktur/copilot/issue/8/insertion-point-not-preserved-when-emojis
    func test_issue_8() {
        // NSString based subsystems count 🔥 as 2 characters
        // we need to use (s as NSString).length instead of count(s) to stay in NSString's 'coordinate system'
        let s = "🔥" as NSString
        expect(s.length) == 2
        expect(count("🔥")) == 1

        var patches = computePatches("123", "🔥123")
        expect(newPosition(3, patches)) == 5 // diff subsytems and NSTextView selections 'see' 🔥 as 2 characters
    }


    // https://bitbucket.org/feinstruktur/copilot/issue/14/client-changes-get-nuked-by-server-always
    func test_issue_14() {
        var serverDoc = Document("foo")
        self.server = DocServer(name: "server", document: serverDoc)

        let client1 = createClient(document: Document(""))
        expect(client1.document.text).toEventually(equal("foo"), timeout: 5)

        let client2 = createClient(document: Document(""))
        expect(client2.document.text).toEventually(equal("foo"), timeout: 5)

        // make quick client changes that fall inside the buffer - this triggers the bug of the _document getting updated and causing the doc to go out of sync with the actual Changeset (baseRef) that's being sent
        client1.update(Document("b"))
        client1.update(Document("ba"))
        client1.update(Document("bar"))

        expect(self.server.document.text).toEventually(equal("bar"), timeout: 1)
        expect(client1.document.text).toEventually(equal("bar"), timeout: 1)
        expect(client2.document.text).toEventually(equal("bar"), timeout: 1)

        // now test the reverse direction making quick changes server side
        self.server.update(Document("f"))
        self.server.update(Document("fo"))
        self.server.update(Document("foo"))

        // the server side quick updates always worked but only because the clients would request a resync when there's a conflict
        expect(self.server.document.text).toEventually(equal("foo"), timeout: 1)
        expect(client1.document.text).toEventually(equal("foo"), timeout: 1)
        expect(client2.document.text).toEventually(equal("foo"), timeout: 1)
    }

    
}
