# vibeos-x86_64-dev.ks — Developer profile for x86_64
# Includes: core + ui + dev tools + AI (no media/hardware bloat)
%include base.ks
%include profiles/packages-core.ks
%include profiles/packages-ui.ks
%include profiles/packages-dev.ks
%include profiles/packages-ai.ks
%include arch/packages-x86_64.ks
%include post/branding.ks
%include post/ui-config.ks
%include post/system-setup.ks
%include post/apps.ks
%include post/ai.ks
%include post/updates.ks
%include post/security.ks
%include post/cleanup.ks
