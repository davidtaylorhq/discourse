import { createWidget } from "discourse/widgets/widget";
import { avatarFor } from "discourse/widgets/post";
import { h } from "virtual-dom";
import { userPath } from "discourse/lib/url";
import hbs from "discourse/widgets/hbs-compiler";

export function avatarAtts(user) {
  return {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower)
  };
}

createWidget("small-user-list", {
  tagName: "div.clearfix",

  buildClasses(atts) {
    return atts.listClassName;
  },

  html(atts) {
    let users = atts.users;
    if (users) {
      const currentUser = this.currentUser;
      if (
        atts.addSelf &&
        !users.some(u => u.username === currentUser.username)
      ) {
        users = users.concat(avatarAtts(currentUser));
      }

      let description = null;

      if (atts.description) {
        description = I18n.t(atts.description, { count: atts.count });
      }

      // oddly post_url is on the user
      let postUrl;
      const icons = users.map(u => {
        postUrl = postUrl || u.post_url;
        return avatarFor.call(this, "small", u);
      });

      if (postUrl) {
        description = h(
          "a",
          { attributes: { href: Discourse.getURL(postUrl) } },
          description
        );
      }

      let buffer = [icons];
      if (description) {
        buffer.push(description);
      }
      return buffer;
    }
  }
});

createWidget("action-link", {
  tagName: "span.action-link",

  buildClasses(attrs) {
    return attrs.className;
  },

  html(attrs) {
    return h("a", [attrs.text, ". "]);
  },

  click() {
    this.sendWidgetAction(this.attrs.action);
  }
});

createWidget("actions-summary-item", {
  tagName: "div.post-action",
  buildKey: attrs => `actions-summary-item-${attrs.id}`,

  defaultState() {
    return { users: [] };
  },

  html(attrs, state) {
    const users = state.users;

    const result = [];
    const action = attrs.action;

    if (users.length === 0) {
      result.push(
        this.attach("action-link", {
          action: "whoActed",
          text: attrs.description
        })
      );
    } else {
      result.push(
        this.attach("small-user-list", {
          users,
          description: `post.actions.people.${action}`
        })
      );
    }

    if (attrs.canUndo) {
      result.push(
        this.attach("action-link", {
          action: "undo",
          className: "undo",
          text: I18n.t(`post.actions.undo.${action}`)
        })
      );
    }

    if (attrs.canDeferFlags) {
      const flagsDesc = I18n.t(`post.actions.defer_flags`, {
        count: attrs.count
      });
      result.push(
        this.attach("action-link", {
          action: "deferFlags",
          className: "defer-flags",
          text: flagsDesc
        })
      );
    }

    return result;
  },

  whoActed() {
    const attrs = this.attrs;
    const state = this.state;
    return this.store
      .find("post-action-user", {
        id: attrs.postId,
        post_action_type_id: attrs.id
      })
      .then(users => {
        state.users = users.map(avatarAtts);
      });
  },

  undo() {
    this.sendWidgetAction("undoPostAction", this.attrs.id);
  },

  deferFlags() {
    this.sendWidgetAction("deferPostActionFlags", this.attrs.id);
  }
});

export default createWidget("actions-summary", {
  tagName: "section.post-actions",
  template: hbs`
    {{#each attrs.actionsSummary as |as|}}
      {{attach widget="actions-summary-item" attrs=as}}
      <div class='clearfix'></div>
    {{/each}}
    {{#if attrs.deleted_at}}
      <div class='post-action deleted-post'>
        {{d-icon "far-trash-alt"}}
        {{avatar size="small" template=attrs.deletedByAvatarTemplate username=attrs.deletedByUsername}}
        {{date attrs.deleted_at}}
      </div>
    {{/if}}
  `
});
