import 'package:flutter/material.dart';

import '../models/sensor_endpoint.dart';

class SensorPanel extends StatelessWidget {
  const SensorPanel({
    super.key,
    required this.sensor,
    required this.reading,
    this.error,
  });

  final SensorEndpoint sensor;
  final Mcp3208Reading reading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final apiLabels = reading.labels;
    final adcLimit = reading.adcCh > 0 ? reading.adcCh : reading.eng.length;
    final indexes = sensor.visibleChannelIndexes(adcChLimit: adcLimit);
    final showWind = sensor.model == SensorModel.mcuEsp32 &&
        sensor.windVisible &&
        reading.wind &&
        reading.eng.length >
            (reading.adcCh > 0
                ? reading.adcCh
                : (apiLabels.isNotEmpty
                    ? apiLabels.length
                    : sensor.defaultLabels().length));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${sensor.dong} · ${sensor.name}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  reading.ready || reading.hasData
                      ? sensor.modelSummary
                      : (error ?? '대기'),
                  style: TextStyle(
                    fontSize: 11,
                    color: reading.ready || reading.hasData
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
                  ),
                ),
              ],
            ),
            Text(
              sensor.displayHost,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            if (error != null && !reading.hasData) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Color(0xFFF87171))),
            ] else if (!reading.hasData) ...[
              const SizedBox(height: 8),
              const Text(
                '아날로그 값 수신 중…',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ] else if (indexes.isEmpty && !showWind) ...[
              const SizedBox(height: 8),
              const Text(
                '표시할 채널이 없습니다. 사이트 편집 → 센서에서 채널을 선택하세요.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in indexes)
                    _Chip(
                      label: sensor.labelForChannel(i, apiLabels: apiLabels),
                      eng: i < reading.eng.length ? reading.eng[i] : null,
                      raw: i < reading.raw.length ? reading.raw[i] : null,
                    ),
                  if (showWind)
                    _Chip(
                      label: SensorEndpoint.windCounterLabel,
                      eng: reading.eng.last,
                      raw: reading.raw.isNotEmpty ? reading.raw.last : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.eng, this.raw});

  final String label;
  final double? eng;
  final int? raw;

  @override
  Widget build(BuildContext context) {
    final engText = eng == null ? '--' : eng!.toStringAsFixed(2);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            engText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (raw != null)
            Text(
              'raw $raw',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }
}
