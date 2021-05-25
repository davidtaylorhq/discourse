import { computed, defineProperty } from "@ember/object";
import Component from "@ember/component";
import { afterRender } from "discourse-common/utils/decorators";
import { buildArgsWithDeprecations } from "discourse/lib/plugin-connectors";
import deprecated from "discourse-common/lib/deprecated";

let _decorators = {};

// Don't call this directly: use `plugin-api/decoratePluginOutlet`
export function addPluginOutletDecorator(outletName, callback) {
  _decorators[outletName] = _decorators[outletName] || [];
  _decorators[outletName].push(callback);
}

export function resetDecorators() {
  _decorators = {};
}

export default Component.extend({
  init() {
    this._super(...arguments);

    const args = this.args || {};
    Object.keys(args).forEach((key) => {
      defineProperty(
        this,
        key,
        computed("args", () => (this.args || {})[key])
      );
    });

    const deprecatedArgs = this.deprecatedArgs || {};
    Object.keys(deprecatedArgs).forEach((key) => {
      defineProperty(
        this,
        key,
        computed("deprecatedArgs", () => {
          deprecated(
            `The ${key} property is deprecated, but is being used in ${this.layoutName}`
          );

          return (this.deprecatedArgs || {})[key];
        })
      );
    });

    const legacyConnectorClass = this.connector.legacyConnectorClass;
    if (legacyConnectorClass) {
      // Legacy - will start printing deprectation notices after 2.8 release
      // See also discourse/lib/plugin-connectors.js
      this.set("actions", legacyConnectorClass.actions || {});
      for (const [name, action] of Object.entries(this.actions)) {
        this.set(name, action);
      }
      const merged = buildArgsWithDeprecations(args, deprecatedArgs);
      legacyConnectorClass.setupComponent?.call(this, merged, this);
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);

    this._decoratePluginOutlets();
  },

  @afterRender
  _decoratePluginOutlets() {
    (_decorators[this.connector.outletName] || []).forEach((dec) =>
      dec(this.element, this.args)
    );
  },

  willDestroyElement() {
    this._super(...arguments);
    if (this.connector.legacyConnectorClass?.teardownComponent) {
      this.connector.legacyConnectorClass.teardownComponent.call(this, this);
    }
  },

  send(name, ...args) {
    // Legacy - will start printing deprectation notices after 2.8 release
    // See also discourse/lib/plugin-connectors.js
    const connectorClass = this.get("connector.connectorClass");
    const action = connectorClass.legacyConnectorClass?.actions[name];
    return action ? action.call(this, ...args) : this._super(name, ...args);
  },
});
