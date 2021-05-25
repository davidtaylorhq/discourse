import Site from "discourse/models/site";
import { buildRawConnectorCache } from "discourse-common/lib/raw-templates";
import deprecated from "discourse-common/lib/deprecated";
import DiscourseConnector, {
  LegacyDiscourseConnector,
} from "discourse/lib/discourse-connector";
import ConnectorComponent from "discourse/components/plugin-connector";

let _connectorCache;
let _rawConnectorCache;
let _extraConnectorClasses = {};
let _classPaths;

export function resetExtraClasses() {
  _extraConnectorClasses = {};
  _classPaths = undefined;
}

// Note: In plugins, define a class by path and it will be wired up automatically
// eg: discourse/connectors/<OUTLET NAME>/<CONNECTOR NAME>
export function extraConnectorClass(name, obj) {
  _extraConnectorClasses[name] = { default: obj };
}

function findOutlets(collection, callback) {
  const disabledPlugins = Site.currentProp("disabled_plugins") || [];

  Object.keys(collection).forEach(function (res) {
    if (res.indexOf("/connectors/") !== -1) {
      // Skip any disabled plugins
      for (let i = 0; i < disabledPlugins.length; i++) {
        if (res.indexOf("/" + disabledPlugins[i] + "/") !== -1) {
          return;
        }
      }

      const segments = res.split("/");
      let outletName = segments[segments.length - 2];
      const uniqueName = segments[segments.length - 1];

      callback(outletName, res, uniqueName);
    }
  });
}

export function clearCache() {
  _connectorCache = null;
  _rawConnectorCache = null;
}

function findModule(outletName, uniqueName) {
  if (!_classPaths) {
    _classPaths = {};

    findOutlets(require._eak_seen, (outlet, res, un) => {
      _classPaths[`${outlet}/${un}`] = requirejs(res);
    });
  }

  const id = `${outletName}/${uniqueName}`;
  return _extraConnectorClasses[id] || _classPaths[id];
}

function buildConnectorCache() {
  _connectorCache = {};

  findOutlets(Ember.TEMPLATES, (outletName, resource, uniqueName) => {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    const foundModule = findModule(outletName, uniqueName);
    let connectorClass = foundModule?.default || DiscourseConnector;
    let connectorComponentClass = foundModule?.component || ConnectorComponent;

    if (!connectorClass.prototype) {
      // Legacy - start printing deprecation notice after 2.8 release

      connectorClass = LegacyDiscourseConnector.extend({
        legacyConnectorClass: connectorClass,
      });
    }

    connectorClass = connectorClass.extend({
      outletName,
    });

    connectorComponentClass = connectorComponentClass.extend({
      layoutName: resource.replace("javascripts/", ""),
      classNames: `${outletName}-outlet ${uniqueName}`,
    });

    const componentName = `discourse-outlet|${outletName}|${uniqueName}`;
    Discourse.register(`component:${componentName}`, connectorComponentClass);

    _connectorCache[outletName].push({
      connectorClass: connectorClass,
      componentName: componentName,
    });
  });
}

export function connectorsFor(outletName) {
  if (!_connectorCache) {
    buildConnectorCache();
  }
  return _connectorCache[outletName] || [];
}

export function rawConnectorsFor(outletName) {
  if (!_rawConnectorCache) {
    _rawConnectorCache = buildRawConnectorCache(findOutlets);
  }
  return _rawConnectorCache[outletName] || [];
}

export function buildArgsWithDeprecations(args, deprecatedArgs) {
  const output = {};

  Object.keys(args).forEach((key) => {
    Object.defineProperty(output, key, { value: args[key] });
  });

  Object.keys(deprecatedArgs).forEach((key) => {
    Object.defineProperty(output, key, {
      get() {
        deprecated(`${key} is deprecated`);

        return deprecatedArgs[key];
      },
    });
  });

  return output;
}
