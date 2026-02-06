## VMware 가상머신에서 ISO file for OL8.10을 설치하는 방법

### 1. Oracle Linux 8.10 ISO 파일 준비


인터넷이 연결된 PC에서 Oracle 공식 사이트 에서 Oracle Linux 8.10 ISO(Full ISO 권장)를 다운로드합니다. USB 드라이브 등 외장 저장매체를 활용해 ISO 파일을 인트라넷(사내망) 환경의 VMware 서버에 전송합니다.


### 2. VMware 가상 머신(VM) 생성
2-1. VMware 관리 콘솔에서 VM 생성
```
새 가상 머신 생성을 선택합니다.
VMware ESXi: vSphere Client에서 “New Virtual Machine” 클릭
VMware Workstation: “Create a New Virtual Machine” 클릭
```  

2-2. OS 타입 지정
```
“Linux” → “Oracle Linux 8(64-bit)” 또는 CentOS/RHEL 8(64-bit) 호환 선택
```

2-3. 하드웨어 설정
```
CPU, 메모리, 디스크 크기 등 환경에 맞게 설정
디스크 용량: 최소 20GB 이상 권장
```
2-4. 가상 CD/DVD 드라이브에 ISO 등록
```
가상 머신의 CD/DVD 드라이브에 다운로드한 Oracle Linux 8.10 ISO 파일을 연결합니다.
EXSi: vSphere Client에서 VM을 선택 → Edit Settings → CD/DVD Drive에서 “Datastore ISO file”에서 선택
  “Connect at Power On” 체크를 반드시 확인하세요.
Workstation: VM 생성 완료 뒤에도, VM 설정 > CD/DVD(IDE/SATA) 항목에서 “Use ISO image file”로 선택 후, 해당 ISO 파일 지정
```
### 3. Oracle Linux 8.10 설치
3-1. VM 부팅
```
VM의 BIOS 또는 구성에서 부팅 순서에 “CD/DVD”가 1순위인지 확인하세요.
ISO 이미지로 부팅되도록 설정하고 가상 머신을 시작합니다.
```
3-1. 설치 마법사 진행
```
“Install Oracle Linux 8.10” 메뉴 선택
언어, 키보드, 시간, 디스크 파티션, 네트워크 등 설치 옵션을 지정
네트워크 설정은 Intranet 내부 IP로 구성: 인터넷 불필요

설치를 시작(“Begin Installation” 클릭)
```
3-1-1 /, /home, /data로 파티션을 나누려면
```
"Installation Destination(설치 대상)" 화면에서
설치할 디스크 선택
Storage Configuration(스토리지 구성): Custom(사용자 정의) 선택
[Done(완료)] 클릭하여 파티셔닝 화면으로 진입

파티션 레이아웃 화면에서 Add mount point(마운트 포인트 추가) 또는 “+” 버튼을 클릭합니다.
아래와 같이 각각의 파티션을 추가합니다.
(필요 용량은 상황에 맞게 지정)
/
Mount Point: /
Desired Capacity: 예) 40 GiB
/home
Mount Point: /home
Desired Capacity: 예) 50 GiB
/data
Mount Point: /data
Desired Capacity: 예) 50 GiB (여유분, 업무 특성에 맞게)

Mount Point 항목에서
“swap”(소문자, 따옴표 없이)로 입력
Desired Capacity(용량) 항목에 원하는 swap 크기를 기입
예: 8 GiB (필요에 따라 2~32GiB 등 알맞게 지정)
File System 또는 Device Type이 “swap”으로 자동 선택됨을 확인
추가한 swap 파티션이 리스트에 있고, 타입이 “swap”/“SWAP”으로 되어 있는지 확인

[Done] 혹은 [Finish partitioning] 등을 클릭
의도한 결과를 한 번 더 검토 후, [Accept Changes(변경 사항 수용)] 혹은 [Apply]로 확정
```

3-3. 사용자 계정, 비밀번호 설정
```
Root 패스워드 및 추가 user 생성
```

3-4. 설치 완료 후 재부팅
```
OS 설치 완료 후, 가상 머신 설정에서 CD/DVD 드라이브의 ISO 연결을 해제하거나, “Physical Drive” 또는 “None”으로 변경.
ISO가 연결된 채로 부팅하면 다시 설치가 시작될 수 있으니 주의.
```
### 4. 설치 완료 후 필수 팁

로컬 레포지터리 사용: 인터넷 없이 패키지 추가·업데이트가 필요하다면, 설치된 ISO 파일을 YUM/DNF 로컬 레포지터리로 마운트하여 활용할 수 있습니다.

4.1 YUM/DNF에서 사용할 수 있도록 .repo 파일을 /etc/yum.repos.d/ 안에 만듭니다.

```
sudo vi /etc/yum.repos.d/local-ol8.repo

[Local-OL8-BaseOS]
name=Oracle Linux 8.10 Local BaseOS
baseurl=file:///mnt/ol8/BaseOS
gpgcheck=0
enabled=1

[Local-OL8-AppStream]
name=Oracle Linux 8.10 Local AppStream
baseurl=file:///mnt/ol8/AppStream
gpgcheck=0
enabled=1
```
4.2 네트워크가 완전히 단절된 환경에서는 기존 온라인 레포지토리를 사용하지 않도록 비활성화합니다

```
sudo dnf config-manager --set-disabled ol8_baseos_latest ol8_appstream
```

4.3 YUM/DNF의 캐시를 정리하고, 제대로 인식되는지 확인합니다.
```
sudo dnf clean all
sudo dnf repolist
```

4.4 패키지 설치 테스트
```
sudo dnf install wget
```

4.5 레포지토리를 항상 사용할 경우 /etc/fstab 등록
```
sudo mkdir -p /mnt/ol8     #이미 있으면 생략

sudo vi /etc/fstab
/경로/OracleLinux-R8-U10-x86_64-dvd.iso  /mnt/ol8  iso9660  loop,ro  0  0

sudo mount -a  # 적용 및 확인
```

4.6 ISO 마운트 경로 확인

```
mount | grep iso
```

### 5. VMware Tools(게스트 툴) 설치

open-vm-tools 패키지는 ISO 내 포함되어 있을 수 있습니다. 또한, VMware 제공 Tools ISO도 인트라넷에 미리 복사해두어야 설치가 원활합니다.

```
sudo dnf install open-vm-tools
sudo systemctl enable --now vmtoolsd
```
### 6. 계정 및 그룹 생성

```
# developers 그룹 생성
sudo groupadd developers

# alice 계정 생성, 기본그룹은 developers, 추가 wheel 그룹
sudo useradd -g developers -G wheel alice

# alice 계정에 비밀번호 설정
sudo passwd alice
``` 
