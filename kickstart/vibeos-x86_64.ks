# vibeos-x86_64.ks — Full profile for x86_64 (default)
# Includes all package groups: core, ui, dev, media, hardware, ai

%include base.ks
%include profiles/packages-core.ks
%include profiles/packages-ui.ks
%include profiles/packages-dev.ks
%include profiles/packages-media.ks
%include profiles/packages-hardware.ks
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
