/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div>
    <h4>OPML</h4>

    <div class="row form-group">
      <label class="col-form-label col-sm-4">エクスポート</label>
      <div class="col-sm-8">
        <a
          class="btn btn-info"
          @click="opmlExport"
        >エクスポート</a>
      </div>
    </div>

    <div class="row form-group">
      <label class="col-form-label col-sm-4">インポート</label>
      <div class="col-sm-8">
        <label>
          <a class="btn btn-light">ファイルの選択</a>
          <input
            ref="file"
            type="file"
            class="d-none"
          >
        </label>
      </div>
    </div>
    <div class="row form-group">
      <div class="col-sm-4" />
      <div class="col-sm-8">
        <button
          class="btn btn-dark"
          @click="opmlImport"
        >
          インポート
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import fileDownload from 'js-file-download';

export default {
  methods: {
    opmlExport: function() {
      const vm = this;
      vm.$root.agent({ url: '/api/opml_export' }).then(data => {
        fileDownload(data.xml, 'opml.xml');
      });
    },
    opmlImport: function() {
      const vm = this;
      const file = vm.$refs.file.files[0];
      const reader = new FileReader();
      reader.addEventListener("load", function () {
        vm.$root.agent({
          url: '/api/opml_import',
          data: {
            xml: reader.result,
          },
        }).then( () => alert("sending done.") );
      }, false);

      if (file) {
        reader.readAsText(file);
      }
    },
  },
}
</script>

