class AppInfo {
  static const name = '스마트팜';
  static const subtitle = '온실 · 카메라 · 센서 통합 제어';
  static const developer = 'judong,kim';
  static const credit = '개발자  judong,kim';
  static const applicationId = 'com.mcopia.smart_farm';

  /// GitHub Pages 등에 올린 개인정보처리방침 URL (Play Console에도 동일 주소).
  static const privacyPolicyUrl = 'https://anyethernet.github.io/smart_farm/';

  static const storeShortDescription =
      '하우스 CCTV·제어보드·센서를 한 화면에서 보고 조작하는 스마트팜 제어 앱입니다.';

  static const storeFullDescription = '''
스마트팜은 비닐하우스·온실에 설치한 IP카메라, ESP32 제어보드, 센서를 한 화면에서 보고 조작하는 제어 앱입니다.

주요 기능
• 하이크비전·한화 등 IP카메라 / NVR 실시간 영상
• TV8BD·TV16AVR 등 제어보드로 개폐기·모터 조작
• 온도·습도 등 센서 값 확인
• 농장(사이트)별 보드·카메라·제어 구성 저장
• 설정 JSON 백업·복원

이용 안내
• 카메라·보드는 이용자가 직접 주소와 로그인 정보를 입력합니다.
• 영상과 제어 명령은 개발자 서버를 거치지 않고 이용자 장비로 바로 연결됩니다.
• 하이크비전, 한화비전 등 제조사 공식 앱이 아닙니다.
• 광고와 추적 SDK를 사용하지 않습니다.

개발자: judong,kim
''';

  static const privacyPolicy = '''
개인정보처리방침

운영자: judong,kim
앱 이름: 스마트팜
애플리케이션 ID: com.mcopia.smart_farm
시행일: 2026-09-15

1. 수집하는 개인정보
이 앱은 개발자 서버로 회원가입을 받지 않으며, 이름, 전화번호, 이메일, 위치, 결제정보, 광고ID를 수집하지 않습니다.

2. 기기 내 저장
농장 이름, 장비 IP, 카메라·제어보드·센서 로그인 정보, 제어 구성만 해당 기기에 저장됩니다. 개발자 서버로 전송하지 않습니다.

3. 인터넷 사용
이용자가 입력한 농장 장비(카메라, 제어보드, 센서)에만 연결합니다. 영상과 제어 명령은 개발자 서버를 거치지 않습니다.

4. 카메라
휴대전화 내장 카메라는 사용하지 않습니다. 등록한 네트워크 카메라 영상은 화면에만 표시하며 개발자에게 업로드하지 않습니다.

5. 설정 백업
내보내기 JSON에는 장비 접속 정보가 포함될 수 있습니다. 신뢰할 수 있는 곳에만 저장하세요.

6. 광고·추적
광고 네트워크, 분석 SDK, 제3자 추적 도구를 사용하지 않습니다.

7. 제3자 제공
개인정보를 수집하지 않으므로 제3자에게 제공하지 않습니다.

8. 보관 기간
앱을 삭제하면 기기 내 설정도 삭제됩니다.

9. 문의
Google Play 개발자 연락처 또는 앱 정보 화면의 개발자 표기(judong,kim)로 문의해 주세요.
''';
}
