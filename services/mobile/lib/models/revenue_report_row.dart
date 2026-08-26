import 'payment_method.dart';

class RevenueReportRow {
  final int id;
  final String receiptNo;
  final String sellerUid;
  final String businessName;
  final String levyTypeName;
  final double amount;
  final PaymentMethod method;
  final String agentName;
  final String paidAt;

  const RevenueReportRow({
    required this.id,
    required this.receiptNo,
    required this.sellerUid,
    required this.businessName,
    required this.levyTypeName,
    required this.amount,
    required this.method,
    required this.agentName,
    required this.paidAt,
  });

  factory RevenueReportRow.fromJson(Map<String, dynamic> json) => RevenueReportRow(
        id: json['id'] as int,
        receiptNo: json['receipt_no'] as String,
        sellerUid: json['seller_uid'] as String,
        businessName: json['business_name'] as String,
        levyTypeName: json['levy_type_name'] as String,
        amount: (json['amount'] as num).toDouble(),
        method: PaymentMethod.fromDb(json['method'] as String),
        agentName: json['agent_name'] as String,
        paidAt: json['paid_at'] as String,
      );
}
