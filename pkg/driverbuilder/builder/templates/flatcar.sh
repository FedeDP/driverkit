#!/bin/bash
set -xeuo pipefail

rm -Rf {{ .DriverBuildDir }}
mkdir {{ .DriverBuildDir }}
rm -Rf /tmp/module-download
mkdir -p /tmp/module-download

curl --silent -SL {{ .ModuleDownloadURL }} | tar -xzf - -C /tmp/module-download
mv /tmp/module-download/*/driver/* {{ .DriverBuildDir }}

cp /driverkit/module-Makefile {{ .DriverBuildDir }}/Makefile
bash /driverkit/fill-driver-config.sh {{ .DriverBuildDir }}

# Fetch the kernel
mkdir /tmp/kernel-download
cd /tmp/kernel-download
curl --silent -SL {{ .KernelDownloadURL }} | tar -Jxf - -C /tmp/kernel-download
rm -Rf /tmp/kernel
mkdir -p /tmp/kernel
mv /tmp/kernel-download/*/* /tmp/kernel

# Change current gcc
ln -sf /usr/bin/gcc-{{ .GCCVersion }} /usr/bin/gcc

curl --silent -o /tmp/kernel.config -SL {{ .KernelConfigURL }}

cd /tmp/kernel
sed -i -e 's|^\(EXTRAVERSION =\).*|\1 -flatcar|' Makefile
make KCONFIG_CONFIG=/tmp/kernel.config oldconfig
make KCONFIG_CONFIG=/tmp/kernel.config modules_prepare

{{ if .BuildModule }}
# Build the module
cd {{ .DriverBuildDir }}
make KERNELDIR=/tmp/kernel
mv {{ .ModuleDriverName }}.ko {{ .ModuleFullPath }}
strip -g {{ .ModuleFullPath }}
# Print results
modinfo {{ .ModuleFullPath }}
{{ end }}

{{ if .BuildProbe }}
# Build the eBPF probe
cd {{ .DriverBuildDir }}/bpf
make LLC=/usr/bin/llc-12 CLANG=/usr/bin/clang-12 CC=/usr/bin/gcc KERNELDIR=/tmp/kernel
ls -l probe.o
{{ end }}