import { connectorsFor } from "discourse/lib/plugin-connectors";
import { getOwner } from "discourse-common/lib/get-owner";
import { LegacyDiscourseConnector } from "discourse/lib/discourse-connector";
/**
   A plugin outlet is an extension point for templates where other templates can
   be inserted by plugins.

   ## Usage

   If your handlebars template has:

   ```handlebars
     {{plugin-outlet name="evil-trout"}}
   ```

   Then any handlebars files you create in the `connectors/evil-trout` directory
   will automatically be appended. For example:

   plugins/hello/assets/javascripts/discourse/templates/connectors/evil-trout/hello.hbs

   With the contents:

   ```handlebars
     <b>Hello World</b>
   ```

   Will insert <b>Hello World</b> at that point in the template.

   ## Disabling

   If a plugin returns a disabled status, the outlets will not be wired up for it.
   The list of disabled plugins is returned via the `Site` singleton.

**/
import Component from "@ember/component";

export default Component.extend({
  tagName: "span",
  connectors: null,

  init() {
    // This should be the future default
    if (this.noTags) {
      this.set("tagName", "");
      this.set("connectorTagName", "");
    }

    this._super(...arguments);
    const name = this.name;

    if (!this.name) {
      return;
    }

    const owner = getOwner(this);
    const connectorInstanceProperties = {
      args: this.args,
      siteSettings: this.siteSettings,
      appEvents: this.appEvents,
      currentUser: this.currentUser,
      site: this.site,
      messageBus: this.messageBus,
      store: this.store,
    };

    const connectors = connectorsFor(name).map(
      ({ connectorClass, componentName }) => {
        let instanceProperties =
          connectorClass.prototype instanceof LegacyDiscourseConnector
            ? { ...connectorInstanceProperties, parentComponent: this }
            : connectorInstanceProperties;

        return {
          connectorClass,
          componentName,
          connectorInstance: connectorClass.create(
            owner.ownerInjection(), // Allow dependency injection
            instanceProperties
          ),
        };
      }
    );
    this.set("connectors", connectors);
  },
});
