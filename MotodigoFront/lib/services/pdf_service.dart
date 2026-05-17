import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateTripTicket({
    required Map<String, dynamic> trip,
    required int bookedSeats,
    required String passengerName,
  }) async {
    final pdf = pw.Document();

    final double unitPrice = double.tryParse(trip['price_per_seat'].toString()) ?? 0;
    final double totalAmount = unitPrice * bookedSeats;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- HEADER PREMIUM ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("MOTODIGO",
                            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text("L'EXCELLENCE DU VOYAGE",
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700, letterSpacing: 1.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("TICKET DE RÉSERVATION",
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text("#${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 15),
                pw.Divider(thickness: 1, color: PdfColors.blue100),
                pw.SizedBox(height: 10),

                // --- PASSAGER & CHAUFFEUR ---
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildPdfInfoLabel("PASSAGER", passengerName.toUpperCase())),
                    pw.Expanded(child: _buildPdfInfoLabel("CHAUFFEUR", (trip['driver_name'] ?? "CHAUFFEUR MOTODIGO").toUpperCase())),
                  ],
                ),

                pw.SizedBox(height: 20),

                // --- ITINÉRAIRE (ZONE BLEUE) ---
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRouteInfo(
                          trip['origin_city'] ?? "DEPART",
                          trip['origin_label'] ?? "Point de ramassage"
                      ),
                      pw.Column(
                          children: [
                            pw.Text(">>>", style: pw.TextStyle(color: PdfColors.blue900, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                            pw.Text("${bookedSeats} PLACE(S)", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                          ]
                      ),
                      _buildRouteInfo(
                          trip['destination_city'] ?? "ARRIVÉE",
                          trip['destination_label'] ?? "Point de dépôt",
                          alignEnd: true
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // --- BAGAGES ET DÉTAILS (NOUVEAU) ---
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoLabel("OPTION BAGAGES", trip['baggage_size'] ?? "Moyen"),
                          pw.SizedBox(height: 8),
                          pw.Text(trip['baggage_details'] ?? "Aucune consigne particulière",
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _buildPdfInfoLabel("VÉHICULE", trip['vehicle_model'] ?? "CONFORT", alignEnd: true),
                          pw.SizedBox(height: 8),
                          pw.Text("IMMATRICULATION VÉRIFIÉE",
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // --- TOTAL PAYÉ (STYLE BANDEAU) ---
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("MONTANT TOTAL PAYÉ",
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("${totalAmount.toInt()} CFA",
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // --- FOOTER & QR CODE ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("MERCI DE VOTRE CONFIANCE.", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text("Support: support@motodigo.com", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        ]
                    ),
                    pw.Column(
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: "MOTODIGO|TRIP-${trip['id']}|PASSENGER-${passengerName}",
                            width: 50,
                            height: 50,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text("VALIDER À L'EMBARQUEMENT", style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold)),
                        ]
                    )
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        name: 'Ticket_MotoDigo_${trip['id']}',
        onLayout: (PdfPageFormat format) async => pdf.save()
    );
  }

  static pw.Widget _buildPdfInfoLabel(String label, String value, {bool alignEnd = false}) {
    return pw.Column(
      crossAxisAlignment: alignEnd ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 6, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildRouteInfo(String city, String detail, {bool alignEnd = false}) {
    return pw.Column(
      crossAxisAlignment: alignEnd ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          city.toUpperCase(),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          width: 80,
          child: pw.Text(
            detail,
            textAlign: alignEnd ? pw.TextAlign.right : pw.TextAlign.left,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }
}