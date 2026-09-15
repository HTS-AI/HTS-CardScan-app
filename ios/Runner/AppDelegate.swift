import Contacts
import ContactsUI
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactViewControllerDelegate {
  private var contactsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "cardscan/contacts",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "openContactEditor" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing contact data", details: nil))
        return
      }
      self?.openContactEditor(args, result: result)
    }
    contactsChannel = channel
  }

  private func openContactEditor(_ contact: [String: Any], result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let status = CNContactStore.authorizationStatus(for: .contacts)
      if self.hasContactsAccess(status) {
        self.presentContactEditor(contact, result: result)
        return
      }
      if status == .notDetermined {
        CNContactStore().requestAccess(for: .contacts) { granted, error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "open_failed", message: error.localizedDescription, details: nil))
              return
            }
            if granted {
              self.presentContactEditor(contact, result: result)
            } else {
              result(FlutterError(code: "denied", message: "Contacts permission was denied.", details: nil))
            }
          }
        }
        return
      }
      result(FlutterError(code: "denied", message: "Contacts permission was denied.", details: nil))
    }
  }

  private func hasContactsAccess(_ status: CNAuthorizationStatus) -> Bool {
    if status == .authorized {
      return true
    }
    if #available(iOS 18.0, *), status == .limited {
      return true
    }
    return false
  }

  private func presentContactEditor(_ data: [String: Any], result: @escaping FlutterResult) {
    guard let host = hostViewController() else {
      result(FlutterError(code: "open_failed", message: "Could not open Contacts.", details: nil))
      return
    }
    let editor = CNContactViewController(forNewContact: makeContact(from: data))
    editor.delegate = self
    editor.contactStore = CNContactStore()
    let nav = UINavigationController(rootViewController: editor)
    nav.modalPresentationStyle = .formSheet
    host.present(nav, animated: true) {
      result(true)
    }
  }

  private func makeContact(from data: [String: Any]) -> CNMutableContact {
    let contact = CNMutableContact()
    let name = ((data["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = name.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    if parts.count >= 2 {
      contact.givenName = parts.dropLast().joined(separator: " ")
      contact.familyName = parts.last ?? ""
    } else {
      contact.givenName = name.isEmpty ? "Unknown" : name
    }

    let org = ((data["org"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !org.isEmpty {
      contact.organizationName = org
    }
    let title = ((data["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !title.isEmpty {
      contact.jobTitle = title
    }

    let phones = stringList(data["phones"])
    if !phones.isEmpty {
      contact.phoneNumbers = phones.map {
        CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0))
      }
    }
    let emails = stringList(data["emails"])
    if !emails.isEmpty {
      contact.emailAddresses = emails.map {
        CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
      }
    }
    let websites = stringList(data["websites"])
    if !websites.isEmpty {
      contact.urlAddresses = websites.map {
        CNLabeledValue(label: CNLabelURLAddressHomePage, value: $0 as NSString)
      }
    }
    return contact
  }

  private func stringList(_ raw: Any?) -> [String] {
    guard let items = raw as? [Any] else { return [] }
    return items.compactMap { value in
      let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
      return text.isEmpty ? nil : text
    }
  }

  private func hostViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    let key = windows.first(where: \.isKeyWindow) ?? windows.first
    var top = key?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
    viewController.dismiss(animated: true)
  }
}
