import EmberObject from "@ember/object";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

const DiscourseConnector = EmberObject.extend({
  router: service(),
  args: null,

  init(properties) {
    this.setProperties(properties);
  },

  @discourseComputed
  shouldRender() {
    return true;
  },
});
DiscourseConnector.prototype.type = "DiscourseConnector";

export default DiscourseConnector;

export const LegacyDiscourseConnector = DiscourseConnector.extend({
  legacyConnectorClass: null,
  parentComponent: null,

  init({ parentComponent } = {}) {
    this.set("parentComponent", parentComponent);
    this._super();
  },

  @discourseComputed("args", "parentComponent")
  shouldRender(args, parentComponent) {
    if (this.legacyConnectorClass?.shouldRender) {
      return this.legacyConnectorClass.shouldRender(args, parentComponent);
    } else {
      return true;
    }
  },
});
