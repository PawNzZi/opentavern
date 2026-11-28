import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/card_import.dart';
import 'package:tavern_app/core/character_png.dart';
import 'package:tavern_app/core/llm.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/novel/generator.dart';
import 'package:tavern_app/core/novel/novel_types.dart';
import 'package:tavern_app/core/novel/publish.dart';
import 'package:tavern_app/data/demo.dart';

class _FakeClient extends LLMClient {
  _FakeClient(this.replies);

  /// 依次返回的回复；用完后重复最后一条。
  final List<String> replies;
  final List<List<Map<String, dynamic>>> calls = [];

  @override
  Stream<String> stream({
    required AppSettings settings,
    required List<Map<String, dynamic>> messages,
    void Function(int inputTokens, int outputTokens)? onUsage,
    bool Function()? shouldAbort,
  }) async* {
    calls.add(messages);
    final reply = replies[calls.length - 1 < replies.length
        ? calls.length - 1
        : replies.length - 1];
    if (reply == '__throw__') {
      throw LLMException('模拟失败');
    }
    if (onUsage != null) onUsage(100, 50);
    yield reply;
  }
}

const _settings = AppSettings(
  api: APISettings(
    provider: 'openai',
    baseUrl: 'https://example.invalid/v1',
    apiKey: 'k',
    model: 'm',
    maxTokens: 512,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('castFallback（单卡定位）', () {
    test('第一人称 + 书名点名角色：char = 美母，user = 我', () {
      final cast = NovelGenerator.castFallback(
        title: '掌中的美母.txt',
        openingExcerpt: '我推开门，看见她坐在窗边。我愣在原地。她没有回头，'
            '只轻声问：“回来了？”我张了张嘴，却没有回答。我该叫她什么？'
            '她是我母亲。',
        candidates: const [
          CastCandidate(
            name: '美母',
            aliases: ['妈妈', '母亲'],
            role: '女主',
            mentions: 30,
          ),
          CastCandidate(name: '小杰', aliases: ['儿子'], role: '男主', mentions: 18),
          CastCandidate(name: '小姨', role: '配角', mentions: 6),
        ],
      );
      expect(cast.character.name, '美母');
      expect(cast.user.name, '我');
      expect(cast.pov, 'first');
      // 第一人称叙述者「小杰」属于 user，不应重复写进世界书。
      expect(cast.user.aliases, contains('小杰'));
      final names = cast.supporting.map((e) => e.name).toList();
      expect(names, contains('小姨'));
      expect(names, isNot(contains('美母')));
      expect(names, isNot(contains('小杰')));
      expect(cast.user.description, isNotEmpty);
    });

    test('第一人称：戏份最高的是叙述者时，char 不能是他', () {
      final cast = NovelGenerator.castFallback(
        title: '掌中的美母.txt',
        openingExcerpt: '我是小杰。我推开门，看见她坐在窗边。我愣在原地。'
            '我没有说话，她也只是看着我。',
        candidates: const [
          CastCandidate(
            name: '小杰',
            aliases: ['儿子'],
            role: '主角（叙述者）',
            gender: '男',
            mentions: 100,
          ),
          CastCandidate(
            name: '母亲',
            aliases: ['妈妈'],
            role: '女主',
            gender: '女',
            mentions: 60,
            relationship: '小杰的母亲',
          ),
          CastCandidate(
            name: '小姨',
            role: '配角',
            gender: '女',
            mentions: 10,
            relationship: '小杰的小姨',
          ),
        ],
      );
      expect(cast.character.name, '母亲');
      expect(cast.user.name, '我');
      expect(cast.user.aliases, contains('小杰'));
      final names = cast.supporting.map((e) => e.name).toList();
      expect(names, contains('小姨'));
      expect(names, isNot(contains('母亲')));
      expect(names, isNot(contains('小杰')));
    });

    test('第一人称没有书名线索时，也不能把叙述者做成角色卡', () {
      final cast = NovelGenerator.castFallback(
        title: '测试书名.txt',
        openingExcerpt: '我是小杰。我推开门，看见她坐在窗边。我愣在原地。'
            '我没有说话，她也只是看着我。我想开口，却不知道说什么。',
        candidates: const [
          CastCandidate(
            name: '小杰',
            role: '主角（叙述者）',
            gender: '男',
            mentions: 100,
          ),
          CastCandidate(
            name: '苏晚',
            role: '女主',
            gender: '女',
            mentions: 40,
            relationship: '小杰的恋人',
          ),
        ],
      );
      expect(cast.character.name, '苏晚');
      expect(cast.user.name, '我');
      expect(cast.supporting.map((e) => e.name), isNot(contains('小杰')));
    });

    test('第三人称：男主给 user、女主给 char', () {
      final cast = NovelGenerator.castFallback(
        title: '总裁的替身新娘.txt',
        openingExcerpt: '陆沉站在落地窗前，看着楼下的雨。苏念推门进来，'
            '把伞放在一边。他抬头看了她一眼，没有说话。',
        candidates: const [
          CastCandidate(name: '陆沉', role: '男主', mentions: 40),
          CastCandidate(name: '苏念', role: '女主', mentions: 35),
          CastCandidate(name: '顾助理', role: '配角', mentions: 8),
        ],
      );
      expect(cast.user.name, '陆沉');
      expect(cast.character.name, '苏念');
      expect(cast.supporting.map((e) => e.name), contains('顾助理'));
    });

    test('用户手动改选优先于本地规则', () {
      final cast = NovelGenerator.castFallback(
        title: '任意书名',
        openingExcerpt: '我看着她。',
        candidates: const [
          CastCandidate(name: '甲', mentions: 10),
          CastCandidate(name: '乙', mentions: 8),
        ],
        charOverride: '乙',
        userOverride: '我',
      );
      expect(cast.character.name, '乙');
      expect(cast.user.name, '我');
    });

    test('completeSupporting 把没被模型列出的角色也补进世界书', () {
      final merged = [
        MergedCharacter(name: '美母', mentions: 30),
        MergedCharacter(name: '小杰', mentions: 18),
        MergedCharacter(name: '小姨', mentions: 6),
        MergedCharacter(name: '邻居', mentions: 2),
      ];
      final cast = const CastResolution(
        character: CastCharacter(name: '美母'),
        user: CastUser(name: '我'),
      );
      final supporting = NovelGenerator.completeSupporting(
        cast: cast,
        merged: merged,
        limit: 10,
      );
      expect(supporting.map((e) => e.name),
          containsAll(['小杰', '小姨', '邻居']));
      expect(supporting.map((e) => e.name), isNot(contains('美母')));
    });

    test('人物关系总览是常驻条目并引用 {{char}}/{{user}}', () {
      final cast = const CastResolution(
        character: CastCharacter(name: '美母'),
        user: CastUser(name: '我'),
        supporting: [
          SupportingCast(
            name: '小姨',
            relationToChar: '与{{char}}是姐妹',
            relationToUser: '{{user}}的小姨',
            importance: 4,
          ),
        ],
      );
      final entry = NovelGenerator.relationshipOverview(
        cast: cast,
        merged: const [],
      );
      expect(entry.constant, true);
      expect(entry.content, contains('{{char}}'));
      expect(entry.content, contains('{{user}}'));
      expect(entry.content, contains('小姨'));
    });
  });

  group('单卡入库与 {{user}} 人格', () {
    test('draftToCharacter 写入角色级人格覆盖', () async {
      const draft = DraftCard(
        name: '美母',
        userName: '小杰',
        userDescription: '你是她的儿子，……',
      );
      final character = await draftToCharacter(draft);
      expect(character.personaNameOverride, '小杰');
      expect(character.personaDescriptionOverride, contains('儿子'));
    });

    test('角色卡 JSON 保留 user 人格，重新导入能还原', () {
      const card = DemoCharacter(
        name: '美母',
        initial: '美',
        title: '',
        tagline: '',
        creator: '小说生成',
        version: '1.0',
        description: 'x',
        greeting: '',
        tags: [],
        lorebook: '未绑定',
        preset: '默认',
        chats: 0,
        tokens: '0',
        colors: [],
        personaNameOverride: '小杰',
        personaDescriptionOverride: '她的儿子',
      );
      final json = card.toCardJson();
      final restored = DemoCharacter.fromCardJson(json);
      expect(restored.personaNameOverride, '小杰');
      expect(restored.personaDescriptionOverride, '她的儿子');
    });

    test('世界书正文不再被 600 字截断', () {
      final merged = MergedLore(
        topic: '长设定',
        contents: ['一' * 1200],
      );
      expect(merged.content.length, 1200);
    });

    test('配置 JSON 往返保留单卡/详细度字段，旧 maxCards 被忽略', () {
      const config = NovelJobConfig(
        filePath: 'a.txt',
        fileName: 'a.txt',
        cardCharacter: '美母',
        cardUser: '我',
        cardUserDescription: '叙述者',
        detail: NovelDetail.standard,
        supportingLimit: 12,
      );
      final json = config.toJson();
      json['maxCards'] = 10; // 旧任务遗留字段
      final restored = NovelJobConfig.fromJson(json);
      expect(restored.cardCharacter, '美母');
      expect(restored.cardUser, '我');
      expect(restored.detail, NovelDetail.standard);
      expect(restored.supportingLimit, 12);
    });
  });

  group('AI 定位与成稿契约', () {
    test('resolveCast 解析 AI 返回的 char / user / supporting', () async {
      final client = _FakeClient([
        '{"pov":"first","confidence":0.9,'
            '"char":{"name":"美母","aliases":["妈妈"],"reason":"书名"},'
            '"user":{"name":"我","aliases":["小杰","儿子"],'
            '"description":"你是她的儿子","reason":"第一人称"},'
            '"supporting":[{"name":"小姨","importance":4,'
            '"relation_to_char":"与美母是姐妹","relation_to_user":"你小姨",'
            '"motivation":"嫉妒","secrets":"秘密","speech_style":"轻声",'
            '"appearance":"红衣","personality":"敏感"}]}',
      ]);
      final gen = NovelGenerator(settings: _settings, client: client);
      final cast = await gen.resolveCast(
        title: '掌中的美母',
        openingExcerpt: '我看着她。',
        candidates: const [
          CastCandidate(name: '美母', aliases: ['妈妈'], role: '女主', mentions: 30),
          CastCandidate(name: '小杰', role: '男主', mentions: 18),
          CastCandidate(name: '小姨', mentions: 6),
        ],
      );
      expect(cast.character.name, '美母');
      expect(cast.user.name, '我');
      expect(cast.user.aliases, containsAll(['小杰', '儿子']));
      expect(cast.user.description, '你是她的儿子');
      expect(cast.supporting.single.name, '小姨');
      expect(cast.source, 'ai');
    });

    test('composeCard 把 user 人格与说话方式写进草稿', () async {
      final client = _FakeClient([
        '{"name":"美母","description":"她是这个家的女主人，也是小杰的母亲。'
            '她总是把情绪藏在温和的语气里，只有在深夜才会露出疲惫。'
            '她与{{user}}之间既有母子间的亲密，也有无法说出口的距离。",'
            '"first_mes":"你回来了？先把湿衣服换了。",'
            '"speech_style":"语气温柔，句尾常带「呢」，叫{{user}}「小杰」。",'
            '"speech_examples":["回来了？饭在锅里呢。","别站着了，过来坐。"]}',
      ]);
      final gen = NovelGenerator(settings: _settings, client: client);
      final card = await gen.composeCard(
        character: MergedCharacter(name: '美母'),
        user: const CastUser(name: '小杰', description: '你是她的儿子'),
        worldSummary: '',
      );
      expect(card.userName, '小杰');
      expect(card.userDescription, '你是她的儿子');
      expect(card.speechStyle, contains('语气温柔'));
      expect(card.speechExamples, contains('回来了？饭在锅里呢。'));
      final systemPrompt = client.calls.single.first['content'].toString();
      expect(systemPrompt, contains('{{user}} = 小杰'));
      expect(systemPrompt, contains('speech_examples'));
    });

    test('模型返回 user 名字/空内容时，仍以 char 为准并兜底正文', () async {
      final client = _FakeClient([
        '{"name":"小杰","description":"","first_mes":""}',
      ]);
      final gen = NovelGenerator(settings: _settings, client: client);
      final card = await gen.composeCard(
        character: MergedCharacter(
          name: '美母',
          personality: ['温柔'],
          relationship: ['小杰的母亲'],
          quotes: ['回来了？'],
        ),
        user: const CastUser(name: '小杰', description: '你是她的儿子'),
        worldSummary: '',
      );
      expect(card.name, '美母');
      expect(card.description, isNotEmpty);
      expect(card.description, contains('美母'));
      expect(card.userName, '小杰');
    });

    test('draftToCharacter 把说话方式并入角色卡 description', () async {
      const draft = DraftCard(
        name: '美母',
        description: '设定正文',
        speechStyle: '语速慢，常用反问。',
        speechExamples: ['回来了？', '你想吃什么？'],
      );
      final character = await draftToCharacter(draft);
      expect(character.description, contains('【习惯的说话方式】'));
      expect(character.description, contains('语速慢，常用反问。'));
      expect(character.description, contains('【说话示例】'));
      expect(character.description, contains('回来了？'));
    });

    test('composeCastLore 失败时用本地模板兜底，正文含关系小标题', () async {
      final client = _FakeClient(['__throw__']);
      final gen = NovelGenerator(settings: _settings, client: client);
      final entries = await gen.composeCastLore(
        supporting: const [
          SupportingCast(
            name: '小姨',
            aliases: ['阿姨'],
            importance: 4,
            relationToChar: '与{{char}}是姐妹',
            relationToUser: '{{user}}的小姨',
            motivation: '嫉妒',
            appearance: '红衣',
            personality: '敏感',
            speechStyle: '轻声，带刺',
            speechExamples: ['你倒是挺会装。', '别碰我。'],
          ),
        ],
        evidence: const {},
        charName: '美母',
        userName: '我',
        title: 't',
        plotSummary: '',
        worldSummary: '',
      );
      expect(entries.single.name, '小姨');
      expect(entries.single.content, contains('【与{{char}}的关系】'));
      expect(entries.single.content, contains('【与{{user}}的关系】'));
      expect(entries.single.content, contains('【习惯的说话方式】'));
      expect(entries.single.content, contains('【说话示例】'));
      expect(entries.single.content, contains('你倒是挺会装。'));
      expect(entries.single.content, contains('红衣'));
      expect(entries.single.keys, contains('阿姨'));
    });
    test('导出的 PNG 卡字段完整：名称/正文/性格/开场白/说话方式', () async {
      const draft = DraftCard(
        name: '美母',
        description: '她是这个家的女主人，也是小杰的母亲。',
        personality: '温柔、克制',
        scenario: '雨夜，家中客厅',
        firstMes: '“回来了？先把湿衣服换了。”',
        mesExample: '<START>\n{{user}}: 我回来了。\n{{char}}: 饭在锅里。',
        alternateGreetings: ['“站在门口做什么？进来。”'],
        speechStyle: '语气温柔，句尾常带「呢」。',
        speechExamples: ['饭在锅里呢。', '别站着了。'],
        tags: ['小说生成', '家庭'],
      );
      final character = await draftToCharacter(draft);
      final png = await buildCharacterCardPng(character);
      final parsed = parseCharacterCard(png, 'card.png');
      expect(parsed, isNotNull);
      expect(parsed!.name, '美母');
      expect(parsed.description, contains('她是这个家的女主人'));
      expect(parsed.description, contains('【习惯的说话方式】'));
      expect(parsed.description, contains('【说话示例】'));
      expect(parsed.personality, '温柔、克制');
      expect(parsed.scenario, '雨夜，家中客厅');
      expect(parsed.greeting, '“回来了？先把湿衣服换了。”');
      expect(parsed.exampleDialogue, contains('饭在锅里'));
      expect(parsed.alternateGreetings, ['“站在门口做什么？进来。”']);
      expect(parsed.tags, contains('小说生成'));
    });

    test('详细模式下世界书条目要求 1000 字以上', () async {
      final client = _FakeClient(['{"entries":[]}']);
      final gen = NovelGenerator(settings: _settings, client: client);
      await gen.composeLore(
        lore: [
          MergedLore(topic: '旧城', keys: {'旧城'}, contents: ['城墙很高。']),
        ],
        maxEntries: 1,
        worldSummary: '旧城',
        detail: NovelDetail.detailed,
      );
      final system = client.calls.single.first['content'].toString();
      expect(system, contains('1000~1300'));
      expect(system, contains('不得低于 1000 字'));

      final client2 = _FakeClient(['{"entries":[]}']);
      final gen2 = NovelGenerator(settings: _settings, client: client2);
      await gen2.composeCastLore(
        supporting: const [SupportingCast(name: '小姨', importance: 4)],
        evidence: const {},
        charName: '美母',
        userName: '我',
        title: 't',
        plotSummary: '',
        worldSummary: '',
        detail: NovelDetail.detailed,
      );
      final system2 = client2.calls.single.first['content'].toString();
      expect(system2, contains('1000~1500'));
      expect(system2, contains('不得低于 1000 字'));
    });

    test('世界书 JSON 不会被误当成角色卡导入', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'name': '旧城世界书',
        'entries': {
          '0': {'key': ['旧城'], 'content': '城墙很高。'},
        },
      })));
      expect(parseCharacterCard(bytes, '世界书-旧城.json'), isNull);
    });

    test('L1 摘录的原话进入归并档案，供说话方式参考', () {
      final blocks = [
        const BlockExtraction(
          blockId: 'c0-p0',
          chapterIndex: 0,
          chapterTitle: '第一章',
          characters: [
            ExtractedCharacter(
              name: '美母',
              speechStyle: '温柔',
              quotes: ['回来了？', '饭在锅里呢。'],
            ),
          ],
        ),
        const BlockExtraction(
          blockId: 'c1-p0',
          chapterIndex: 1,
          chapterTitle: '第二章',
          characters: [
            ExtractedCharacter(name: '美母', quotes: ['别站着了。']),
          ],
        ),
      ];
      final merged = NovelGenerator.mergeCharacters(blocks);
      expect(merged.single.quotes, containsAll(['回来了？', '饭在锅里呢。', '别站着了。']));
      expect(merged.single.profileText, contains('原话示例'));
    });
  });
}
