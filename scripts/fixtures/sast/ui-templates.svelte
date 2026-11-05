<!-- META-ONLY fixture for security/sast/ui-templates.yml (EVOL-074) -->
<script>
  export let body = '';
</script>

<!-- ruleid: ui-templates-svelte-raw-html -->
<div>{@html body}</div>
<!-- ok: ui-templates-svelte-raw-html -->
<div>{body}</div>
