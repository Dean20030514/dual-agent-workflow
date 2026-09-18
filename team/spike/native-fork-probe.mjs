// Acceptance-only overlay: create one real completed parent turn before the
// stock headless runner submits its normal task. All inference stays in DSH.
import { writeFileSync } from 'node:fs';

export const name = 'team-fork-inheritance-probe';
export const inject = ['agents'];

export function apply(ctx, config) {
  const create = ctx.agents.create.bind(ctx.agents);
  const evidence = { parent: null, children: [] };
  const save = () => writeFileSync(config.evidence, JSON.stringify(evidence, null, 2), 'utf8');
  ctx.agents.create = async options => {
    const handle = await create(options);
    const agent = handle.agent;
    const idle = agent.whenIdle.bind(agent);
    if (options.parentAgent) {
      const seed = options.seed ?? [];
      const record = {
        id: options.sessionId, depth: options.agentOptions.subagentDepth,
        provider: options.agentOptions.provider, model: options.agentOptions.model,
        seed_events: seed.length, seed_last_type: seed.at(-1)?.type,
        seed_contains_marker: JSON.stringify(seed).includes(config.marker),
        prompt_contains_marker: null, completed: false, recalled_marker: false,
      };
      evidence.children.push(record); save();
      const followup = agent.followup.bind(agent);
      agent.followup = message => {
        record.prompt_contains_marker = JSON.stringify(message).includes(config.marker);
        save(); return followup(message);
      };
      agent.whenIdle = async (...args) => {
        await idle(...args);
        const own = agent.session.snapshotEvents().slice(seed.length);
        const final = own.findLast(event => event.type === 'assistant/message');
        const text = final?.data.message.content.filter(block => block.type === 'text').map(block => block.text).join('') ?? '';
        record.completed = own.findLast(event => event.type === 'turn/end')?.data.reason.kind === 'completed';
        record.recalled_marker = text.trim() === config.marker;
        record.own_tool_calls = own.filter(event => event.type === 'tool/call').length;
        save();
      };
    } else {
      const { createUserMessage } = await import(config.llmModule);
      await idle();
      agent.followup(createUserMessage({ content: [{ type: 'text', text:
        `Remember this synthetic acceptance marker for a later turn: ${config.marker}. Do not use any tools or write any files. Reply only READY.` }], source: { kind: 'user' } }));
      await idle();
      const events = agent.session.snapshotEvents();
      evidence.parent = {
        id: options.sessionId, provider: options.agentOptions.provider, model: options.agentOptions.model,
        completed: events.findLast(event => event.type === 'turn/end')?.data.reason.kind === 'completed',
        completed_prefix_events: events.length, tool_calls: events.filter(event => event.type === 'tool/call').length,
      };
      save();
      if (!evidence.parent.completed || evidence.parent.tool_calls !== 0) throw new Error('Invalid fork probe warm-up');
    }
    return handle;
  };
  ctx.on('dispose', () => { ctx.agents.create = create; });
}
