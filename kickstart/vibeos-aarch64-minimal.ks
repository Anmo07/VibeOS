# vibeos-aarch64-minimal.ks — Minimal profile for aarch64
%include base.ks
%include profiles/packages-core.ks
%include profiles/packages-ui.ks
%include arch/packages-aarch64.ks
%include post/branding.ks
%include post/ui-config.ks
%include post/system-setup.ks
%include post/security.ks
%include post/cleanup.ks
