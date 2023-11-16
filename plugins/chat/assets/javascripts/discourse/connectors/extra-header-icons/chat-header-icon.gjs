import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import Icon from "../../components/chat/header/icon";

export default class ChatHeaderIconConnector extends Component {
  @service chat;

  <template>
    {{#if this.chat.userCanChat}}
      <Icon />
    {{/if}}
  </template>
}
