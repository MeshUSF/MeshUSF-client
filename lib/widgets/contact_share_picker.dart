import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../utils/contact_qr.dart';
import 'contact_share_button.dart';
import 'mesh_ui.dart';

class ContactSharePicker extends StatefulWidget {
  const ContactSharePicker({super.key});

  @override
  State<ContactSharePicker> createState() => _ContactSharePickerState();
}

class _ContactSharePickerState extends State<ContactSharePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final connector = context.watch<MeshCoreConnector>();
    final contacts =
        connector.contacts.where((contact) {
          return contact.isActive &&
              (contact.name.toLowerCase().contains(_query) ||
                  contact.publicKeyHex.contains(_query));
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          BottomSheetHeader(title: context.l10n.chat_shareContact),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.contacts_searchContactsNoNumber,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? context.l10n.contacts_noContacts
                          : context.l10n.contacts_noContactsMatchFilter,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final text = buildContactShare(
                        contact.publicKey,
                        contact.name,
                        type: contact.type,
                      );
                      final scanned = text == null
                          ? null
                          : parseContactShare(text);
                      return ContactShareButton(
                        name: scanned?.name ?? contact.name,
                        publicKeyHex: contact.publicKeyHex,
                        label: text == null
                            ? context.l10n.chat_contactCannotShare
                            : context.l10n.chat_shareContact,
                        icon: Icons.share_outlined,
                        onPressed: connector.isConnected && text != null
                            ? () => Navigator.pop<Contact>(context, contact)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
