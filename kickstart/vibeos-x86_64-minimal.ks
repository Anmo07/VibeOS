# vibeos-x86_64-minimal.ks — Minimal profile for x86_64
%include base.ks
%include profiles/packages-core.ks
%include profiles/packages-ui.ks
%include arch/packages-x86_64.ks
%include post/branding.ks
%include post/ui-config.ks
%include post/system-setup.ks
%include post/security.ks
%include post/cleanup.ks
