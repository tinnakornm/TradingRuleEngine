//+------------------------------------------------------------------+
//| include/evidence.mqh                                             |
//| Reusable explainable rule evidence model                         |
//+------------------------------------------------------------------+
#ifndef TRE_EVIDENCE_MQH
#define TRE_EVIDENCE_MQH

#define TRE_STATUS_PASS "PASS"
#define TRE_STATUS_FAIL "FAIL"
#define TRE_STATUS_WAIT "WAIT"
#define TRE_STATUS_DISABLED "DISABLED"
#define TRE_STATUS_NA "N/A"

#define TRE_TREND_EVIDENCE_COUNT 8
#define TRE_REGIME_EVIDENCE_COUNT 6
#define TRE_ENGINE_SCORE_COUNT 4

struct TRE_EvidenceItem
{
   string name;
   string status;
   double score;
   double maxScore;
   string reason;
   string missing;
};

struct TRE_EngineScoreItem
{
   string name;
   double rawScore;
   double rawMax;
   bool enabled;
   double configuredWeight;
   double effectiveWeight;
   double weightedScore;
   string status;
   string reason;
};

void TRE_SetEvidenceItem(TRE_EvidenceItem &item,
                         string name,
                         string status,
                         double score,
                         double maxScore,
                         string reason,
                         string missing)
{
   item.name = name;
   item.status = status;
   item.score = score;
   item.maxScore = maxScore;
   item.reason = reason;
   item.missing = missing;
}

void TRE_SetEngineScoreItem(TRE_EngineScoreItem &item,
                            string name,
                            double rawScore,
                            double rawMax,
                            bool enabled,
                            double configuredWeight,
                            string status,
                            string reason)
{
   item.name = name;
   item.rawScore = rawScore;
   item.rawMax = rawMax;
   item.enabled = enabled;
   item.configuredWeight = configuredWeight;
   item.effectiveWeight = 0;
   item.weightedScore = 0;
   item.status = status;
   item.reason = reason;
}

#endif
