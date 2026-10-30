import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import type AdminAreaSettingsBaseController from "discourse/admin/controllers/admin-area-settings-base";

const JtechToolsGhostEmbeds: TemplateOnlyComponent<{
  Args: { controller: AdminAreaSettingsBaseController };
}> = <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories={{array "jtech_ghost_embeds"}}
    @filter={{@controller.filter}}
    @path="/admin/plugins/jtech-tools/ghost-embeds"
    @showBreadcrumb={{false}}
  />
</template>;

export default JtechToolsGhostEmbeds;
