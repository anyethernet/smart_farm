# 스마트팜 Flutter 앱 (`smart_farm`)

하이크비전 실시간 영상 + ESP32-P4-ETH(TV8BD / TV16AVR) 웹 IOCTL 제어용 Android/iOS 앱입니다.

## 기능

- **사이트별 설정**: ESP32 IP/도메인 + 포트, 웹 로그인 ID/PW
- **영상 소스 정의**: Hikvision RTSP / Snapshot / 사용자 URL — 여러 대 등록 가능
- **제어 요소 정의**: 천창·측창·환기팬 등 이름을 붙이고 ESP32 모터쌍/핀에 매핑
- **프로토콜** (`esp32-p4-ETH` `Webpage.h` 호환)
  - `POST /login/check` — 로그인
  - `GET /io/state` — 채널 상태
  - `POST /config/io/ctrl` — `pair`+`action` 또는 `pin`+`val`

ESP32 Model이 **TV8BD** 또는 **TV16AVR**일 때 제어가 동작합니다.

## 실행

```bat
cd C:\flutter_project\smart_farm
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat run
```

폰과 ESP32·카메라가 같은 내부망에 있어야 합니다.

## GitHub에서 받아서 작업

```bat
git clone https://github.com/anyethernet/smart_farm.git
cd smart_farm
flutter pub get
```

Play 서명용 `upload-keystore.jks`와 `key.properties`는 저장소에 없습니다. 집 PC에서는 이 컴퓨터의 키스토어를 복사한 뒤 `key.properties.example`을 `key.properties`로 복사해 경로·비밀번호를 맞추면 됩니다.

## 설정 위치

앱 우측 상단 톱니 → 사이트 선택/추가 → **영상·제어 정의**에서 카메라와 천창/측창을 편집합니다.
