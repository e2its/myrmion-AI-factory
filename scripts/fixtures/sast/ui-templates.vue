<!-- META-ONLY fixture for security/sast/ui-templates.yml (EVOL-074) -->
<template>
  <section>
    <!-- ruleid: ui-templates-vue-raw-html -->
    <div v-html="comment.body"></div>
    <!-- ok: ui-templates-vue-raw-html -->
    <div v-text="comment.body"></div>
    <!-- ok: ui-templates-vue-raw-html -->
    <p>{{ comment.body }}</p>
  </section>
</template>
