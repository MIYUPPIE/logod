class ActiveAgentSummary {
  final int agentId;
  final String name;
  final String? lastSeenAt;
  final double todayTotal;

  const ActiveAgentSummary({
    required this.agentId,
    required this.name,
    required this.lastSeenAt,
    required this.todayTotal,
  });

  factory ActiveAgentSummary.fromJson(Map<String, dynamic> json) => ActiveAgentSummary(
        agentId: json['agent_id'] as int,
        name: json['name'] as String,
        lastSeenAt: json['last_seen_at'] as String?,
        todayTotal: (json['today_total'] as num).toDouble(),
      );
}

class FlaggedSummaryItem {
  final String type;
  final int id;
  final String reason;

  const FlaggedSummaryItem({required this.type, required this.id, required this.reason});

  factory FlaggedSummaryItem.fromJson(Map<String, dynamic> json) => FlaggedSummaryItem(
        type: json['type'] as String,
        id: json['id'] as int,
        reason: json['reason'] as String,
      );
}

class DashboardSummary {
  final double todayTotalAmount;
  final int todayPaymentCount;
  final List<ActiveAgentSummary> activeAgents;
  final int pendingSyncCount;
  final List<FlaggedSummaryItem> flagged;

  const DashboardSummary({
    required this.todayTotalAmount,
    required this.todayPaymentCount,
    required this.activeAgents,
    required this.pendingSyncCount,
    required this.flagged,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        todayTotalAmount: (json['today_total_amount'] as num).toDouble(),
        todayPaymentCount: json['today_payment_count'] as int,
        activeAgents: (json['active_agents'] as List<dynamic>)
            .map((e) => ActiveAgentSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        pendingSyncCount: json['pending_sync_count'] as int,
        flagged: (json['flagged'] as List<dynamic>)
            .map((e) => FlaggedSummaryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
