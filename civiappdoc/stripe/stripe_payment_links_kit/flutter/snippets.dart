// Flutter snippets for opening Stripe Payment Links

import 'package:url_launcher/url_launcher.dart';

Future<void> openPaymentLink(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw 'Could not launch $url';
  }
}

// Example UI idea: list tiles reading from Firestore (pseudo)
/*
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('salon_payment_links')
    .where('salonId', isEqualTo: currentSalonId)
    .where('enabled', isEqualTo: true)
    .snapshots(),
  builder: (context, snap) {
    if (!snap.hasData) return CircularProgressIndicator();
    final docs = snap.data!.docs;
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i].data() as Map<String, dynamic>;
        return ListTile(
          title: Text(d['title'] ?? ''),
          subtitle: Text('${d['price']} ${d['currency']}'),
          trailing: TextButton(
            onPressed: () => openPaymentLink(d['stripe_link_url']),
            child: const Text('Paga ora'),
          ),
        );
      },
    );
  },
);
*/
