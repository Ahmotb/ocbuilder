#!/bin/bash

prompt() {
    dialogTitle="OCBuilder"
    authPass=$(/usr/bin/osascript <<EOT
        tell application "System Events"
            activate
            repeat
                display dialog "This application requires administrator privileges. Please enter your administrator account password below to continue:" ¬
                    default answer "" ¬
                    with title "$dialogTitle" ¬
                    with hidden answer ¬
                    buttons {"Quit", "Continue"} default button 2
                if button returned of the result is "Quit" then
                    return 1
                    exit repeat
                else if the button returned of the result is "Continue" then
                    set pswd to text returned of the result
                    set usr to short user name of (system info)
                    try
                        do shell script "echo test" user name usr password pswd with administrator privileges
                        return pswd
                        exit repeat
                    end try
                end if
            end repeat
        end tell
    EOT
    )

    if [ "$authPass" == 1 ]
    then
        /bin/echo "User aborted. Exiting..."
        exit 0
    fi

    sudo () {
        /bin/echo $authPass | /usr/bin/sudo -S "$@"
    }
}

BUILD_DIR="${1}/OCBuilder_Clone"
FINAL_DIR="${2}/Release_Without_Kext_OCBuilder_Completed"

installnasm () {
    pushd /tmp >/dev/null
    rm -rf nasm-mac64.zip
    curl -OL "https://github.com/acidanthera/ocbuild/raw/master/external/nasm-mac64.zip" || exit 1
    nasmzip=$(cat nasm-mac64.zip)
    rm -rf nasm-*
    curl -OL "https://github.com/acidanthera/ocbuild/raw/master/external/${nasmzip}" || exit 1
    unzip -q "${nasmzip}" nasm*/nasm nasm*/ndisasm || exit 1
    if [ -d /usr/local/bin ]; then
        sudo mv nasm*/nasm /usr/local/bin/ || exit 1
        sudo mv nasm*/ndisasm /usr/local/bin/ || exit 1
        rm -rf "${nasmzip}" nasm-*
    else
        sudo mkdir -p /usr/local/bin || exit 1
        sudo mv nasm*/nasm /usr/local/bin/ || exit 1
        sudo mv nasm*/ndisasm /usr/local/bin/ || exit 1
        rm -rf "${nasmzip}" nasm-*
    fi
}

installmtoc () {
    rm -f mtoc mtoc-mac64.zip
    curl -OL "https://github.com/acidanthera/ocbuild/raw/master/external/mtoc-mac64.zip" || exit 1
    unzip -q mtoc-mac64.zip mtoc || exit 1
    sudo cp mtoc /usr/local/bin/mtoc || exit 1
    sudo mv mtoc /usr/local/bin/mtoc.NEW || exit 1
}

ocshellpackage() {
    pushd "$1" >/dev/null || exit 1
    rm -rf tmp >/dev/null || exit 1
    mkdir -p tmp/Tools >/dev/null || exit 1
    cp Shell_EA4BB293-2D7F-4456-A681-1F22F42CD0BC.efi tmp/Tools/Shell.efi >/dev/null || exit 1
    echo "$3" > tmp/UDK.hash >/dev/null || exit 1
    pushd tmp >/dev/null || exit 1
    zip -qry -FS ../"OpenCoreShell-${PKGVER}-${2}.zip" * >/dev/null || exit 1
    popd >/dev/null || exit 1
    rm -rf tmp >/dev/null || exit 1
    popd >/dev/null || exit 1
}

applesupportpackage() {
    pushd "$1" || exit 1
    rm -rf tmp || exit 1
    mkdir -p tmp/Drivers || exit 1
    mkdir -p tmp/Tools   || exit 1
    cp AudioDxe.efi tmp/Drivers/          || exit 1
    cp ApfsDriverLoader.efi tmp/Drivers/  || exit 1
    cp VBoxHfs.efi tmp/Drivers/           || exit 1
    pushd tmp || exit 1
    zip -qry -FS ../"AppleSupport-${ver}-${2}.zip" * || exit 1
    popd || exit 1
    rm -rf tmp || exit 1
    popd || exit 1
}

opencorepackage() {
    selfdir=$(pwd)
    pushd "$1" || exit 1
    rm -rf tmp || exit 1
    mkdir -p tmp/EFI || exit 1
    mkdir -p tmp/EFI/OC || exit 1
    mkdir -p tmp/EFI/OC/ACPI || exit 1
    mkdir -p tmp/EFI/OC/Drivers || exit 1
    mkdir -p tmp/EFI/OC/Kexts || exit 1
    mkdir -p tmp/EFI/OC/Tools || exit 1
    mkdir -p tmp/EFI/BOOT || exit 1
    mkdir -p tmp/Docs/AcpiSamples || exit 1
    mkdir -p tmp/Utilities || exit 1
    cp OpenCore.efi tmp/EFI/OC/ || exit 1
    cp BOOTx64.efi tmp/EFI/BOOT/ || exit 1
    cp AppleUsbKbDxe.efi tmp/EFI/OC/Drivers/ || exit 1
    cp FwRuntimeServices.efi tmp/EFI/OC/Drivers/ || exit 1
    cp HiiDatabase.efi tmp/EFI/OC/Drivers/ || exit 1
    cp NvmExpressDxe.efi tmp/EFI/OC/Drivers/ || exit 1
    cp XhciDxe.efi tmp/EFI/OC/Drivers/ || exit 1
    cp BootKicker.efi tmp/EFI/OC/Tools/ || exit 1
    cp CleanNvram.efi tmp/EFI/OC/Tools/ || exit 1
    cp GopStop.efi tmp/EFI/OC/Tools/ || exit 1
    cp HdaCodecDump.efi tmp/EFI/OC/Tools/ || exit 1
    cp VerifyMsrE2.efi tmp/EFI/OC/Tools/ || exit 1
    cp "${selfdir}/Docs/Configuration.pdf" tmp/Docs/ || exit 1
    cp "${selfdir}/Docs/Differences/Differences.pdf" tmp/Docs/ || exit 1
    cp "${selfdir}/Docs/Sample.plist" tmp/Docs/ || exit 1
    cp "${selfdir}/Docs/SampleFull.plist" tmp/Docs/ || exit 1
    cp "${selfdir}/Changelog.md" tmp/Docs/ || exit 1
    cp -r "${selfdir}/Docs/AcpiSamples/" tmp/Docs/AcpiSamples/ || exit 1
    cp -r "${selfdir}/Utilities/BootInstall" tmp/Utilities/ || exit 1
    cp -r "${selfdir}/Utilities/CreateVault" tmp/Utilities/ || exit 1
    cp -r "${selfdir}/Utilities/LogoutHook" tmp/Utilities/ || exit 1
    pushd tmp || exit 1
    zip -qry -FS ../"OpenCore-${ver}-${2}.zip" * || exit 1
    popd || exit 1
    rm -rf tmp || exit 1
    popd || exit 1
}

ocshelludkclone() {
    echo "Cloning AUDK Repo into OpenCoreShell..."
    git clone -q https://github.com/acidanthera/audk UDK -b master --depth=1
}

opencoreshellclone() {
    echo "Cloning OpenCoreShell Git repo..."
    git clone -q https://github.com/acidanthera/OpenCoreShell.git
}

applesupportpkgclone() {
    echo "Cloning AppleSupportPkg SupportPkgs into AUDK..."
    git clone -q https://github.com/acidanthera/EfiPkg EfiPkg -b master --depth=1
    git clone -q https://github.com/acidanthera/OpenCorePkg OpenCorePkg -b master --depth=1
}

applesupportudkclone() {
    echo "Cloning AUDK Repo into AppleSupportPkg..."
    git clone -q https://github.com/acidanthera/audk UDK -b master --depth=1
}

applesupportclone() {
    echo "Cloning AppleSupportPkg Git repo..."
    git clone -q https://github.com/acidanthera/AppleSupportPkg.git
}

opencorepkgclone() {
    echo "Cloning OpenCorePkg SupportPkgs into AUDK..."
    git clone -q https://github.com/acidanthera/EfiPkg EfiPkg -b master --depth=1
    git clone -q https://github.com/acidanthera/MacInfoPkg MacInfoPkg -b master --depth=1
}

opencoreudkclone() {
    echo "Cloning AUDK Repo into OpenCorePkg..."
    git clone -q https://github.com/acidanthera/audk UDK -b master --depth=1
}

opencoreclone() {
    echo "Cloning OpenCorePkg Git repo..."
    git clone -q https://github.com/acidanthera/OpenCorePkg.git
}

ocbinarydataclone () {
    echo "Cloning OcBinaryData Git repo..."
    git clone -q https://github.com/acidanthera/OcBinaryData.git
}

copyBuildProducts() {
    echo "Copying compiled products into EFI Structure folder in ${FINAL_DIR}..."
    cp "${BUILD_DIR}"/OpenCorePkg/Binaries/RELEASE/*.zip "${FINAL_DIR}/"
    cd "${FINAL_DIR}/"
    unzip *.zip  >/dev/null || exit 1
    rm -rf *.zip
    cp -r "${BUILD_DIR}/OpenCoreShell/Binaries/RELEASE/Shell_EA4BB293-2D7F-4456-A681-1F22F42CD0BC.efi" "${FINAL_DIR}"/EFI/OC/Tools/Shell.efi
    cd "${BUILD_DIR}"/AppleSupportPkg/Binaries/RELEASE
    rm -rf "${BUILD_DIR}"/AppleSupportPkg/Binaries/RELEASE/Drivers
    rm -rf "${BUILD_DIR}"/AppleSupportPkg/Binaries/RELEASE/Tools
    unzip *.zip  >/dev/null || exit 1
    cp -r "${BUILD_DIR}"/AppleSupportPkg/Binaries/RELEASE/Drivers/*.efi "${FINAL_DIR}"/EFI/OC/Drivers
    cp -r "${BUILD_DIR}"/OcBinaryData/Resources "${FINAL_DIR}"/EFI/OC/
    cp -r "${BUILD_DIR}"/OcBinaryData/Drivers/*.efi "${FINAL_DIR}"/EFI/OC/Drivers
    echo "All Done!..."
}

if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}"
else
    rm -rf "${BUILD_DIR}/"
    mkdir -p "${BUILD_DIR}"
fi

cd "${BUILD_DIR}"

if [ "$(nasm -v)" = "" ]; then
    echo "NASM is missing!, installing..."
    prompt
    installnasm
else
    echo "NASM Already Installed..."
fi

if [ "$(which mtoc)" == "" ]; then
    echo "MTOC is missing!, installing..."
    prompt
    installmtoc
else
    echo "MTOC Already Installed..."
fi

cd "${BUILD_DIR}"

opencoreclone
unset WORKSPACE
unset PACKAGES_PATH
cd "${BUILD_DIR}/OpenCorePkg"
mkdir Binaries
cd Binaries
ln -s ../UDK/Build/OpenCorePkg/RELEASE_XCODE5/X64 RELEASE
cd ..
opencoreudkclone
cd UDK
opencorepkgclone
ln -s .. OpenCorePkg
make -C BaseTools >/dev/null || exit 1
sleep 1
export NASM_PREFIX=/usr/local/bin/
source edksetup.sh --reconfig >/dev/null
sleep 1
echo "Compiling the latest commited Release version of OpenCorePkg..."
build -a X64 -b RELEASE -t XCODE5 -p OpenCorePkg/OpenCorePkg.dsc >/dev/null || exit 1
cd .. >/dev/null || exit 1
opencorepackage "Binaries/RELEASE" "RELEASE" >/dev/null || exit 1

if [ "$BUILD_UTILITIES" = "1" ]; then
    UTILS=(
        "AppleEfiSignTool"
        "EfiResTool"
        "readlabel"
        "RsaTool"
    )

    cd Utilities || exit 1
    for util in "${UTILS[@]}"; do
        cd "$util" || exit 1
        make || exit 1
        cd - || exit 1
    done
fi

cd "${BUILD_DIR}"/OpenCorePkg/Library/OcConfigurationLib || exit 1
./CheckSchema.py OcConfigurationLib.c >/dev/null || exit 1

cd "${BUILD_DIR}"

applesupportclone
unset WORKSPACE
unset PACKAGES_PATH
cd "${BUILD_DIR}/AppleSupportPkg"
mkdir Binaries >/dev/null || exit 1
cd Binaries >/dev/null || exit 1
ln -s ../UDK/Build/AppleSupportPkg/RELEASE_XCODE5/X64 RELEASE >/dev/null || exit 1
cd .. >/dev/null || exit 1
applesupportudkclone
cd UDK
applesupportpkgclone
ln -s .. AppleSupportPkg >/dev/null || exit 1
make -C BaseTools >/dev/null || exit 1
sleep 1
unset WORKSPACE
unset EDK_TOOLS_PATH
export NASM_PREFIX=/usr/local/bin/
source edksetup.sh --reconfig >/dev/null || exit 1
sleep 1
echo "Compiling the latest commited Release version of AppleSupportPkg..."
build -a X64 -b RELEASE -t XCODE5 -p AppleSupportPkg/AppleSupportPkg.dsc >/dev/null || exit 1
cd .. >/dev/null || exit 1
applesupportpackage "Binaries/RELEASE" "RELEASE" >/dev/null || exit 1

cd "${BUILD_DIR}"

opencoreshellclone
unset WORKSPACE
unset PACKAGES_PATH
cd "${BUILD_DIR}/OpenCoreShell"
mkdir Binaries >/dev/null || exit 1
cd Binaries >/dev/null || exit 1
ln -s ../UDK/Build/Shell/RELEASE_XCODE5/X64 RELEASE >/dev/null || exit 1
cd .. >/dev/null || exit 1
ocshelludkclone
cd UDK
HASH=$(git rev-parse origin/master)
ln -s .. AppleSupportPkg >/dev/null || exit 1
make -C BaseTools >/dev/null || exit 1
sleep 1
unset WORKSPACE
unset EDK_TOOLS_PATH
export NASM_PREFIX=/usr/local/bin/
source edksetup.sh --reconfig >/dev/null
sleep 1
for i in ../Patches/* ; do
    git apply "$i" --whitespace=fix >/dev/null || exit 1
    git add * >/dev/null || exit 1
    git commit -m "Applied patch $i" >/dev/null || exit 1
done
touch patches.ready
echo "Compiling the latest commited Release version of OpenCoreShellPkg..."
build -a X64 -b RELEASE -t XCODE5 -p ShellPkg/ShellPkg.dsc >/dev/null || exit 1
cd .. >/dev/null || exit 1
ocshellpackage "Binaries/RELEASE" "RELEASE" "$HASH" >/dev/null || exit 1

cd "${BUILD_DIR}"

ocbinarydataclone

if [ ! -d "${FINAL_DIR}" ]; then
    mkdir -p "${FINAL_DIR}"
    copyBuildProducts
#  rm -rf "${BUILD_DIR}/"
    open -a Safari https://khronokernel.github.io/Opencore-Vanilla-Desktop-Guide/
else
    rm -rf "${FINAL_DIR}"/*
    copyBuildProducts
#  rm -rf "${BUILD_DIR}/"
    open -a Safari https://khronokernel.github.io/Opencore-Vanilla-Desktop-Guide/
fi

