#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""补丁：为《救主耶稣也是主、更是君王！》补 en 详情页缺失 3 章（disciple/works/question）
   —— en 静态页仅有 intro/mission/faith 3 章，此处补翻译注入 appdata.json。
   运行：cd <仓库根> && python3 tools/patch_sermon10_en.py
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPDATA = os.path.join(ROOT, 'appdata', 'appdata.json')

EN = {
 'disciple': {
   'title': 'Discipleship',
   'blocks': [
     ('p', "Only by becoming disciples can we preach the gospel, heal the sick, and make disciples. If Christians are unwilling to pay the cost of following Jesus as disciples, they remain at the very beginning of the teaching of Christ."),
     ('p', "This unwillingness to pay the cost of following Jesus is connected, to some extent, with theological history, because the pastors and teachers who instruct the church all have some theological background—and some of those theologies even conflict with one another."),
     ('p', "I believe that theology is good theology only when it returns to the Bible. Theology that departs from the Bible, goes beyond the Bible, or denies the Bible is neither good theology nor correct theology."),
   ]},
 'works': {
   'title': 'Faith and Works',
   'blocks': [
     ('p', "We see that Romans 6:15 makes the meaning clear: although we are justified by faith and are no longer under the law but under grace, we still must not sin!"),
     ('p', "Peter says that through knowing Jesus we escape the corruption of the world; but if we are later entangled in it and overcome by the world's sin, our end state is worse than before we believed."),
     ('p', "Let us see what James, the Lord's brother, says."),
     ('p', "James, the brother of Jesus, says that faith without works is dead; faith must work together with works, and faith is made complete through works. After we believe in Jesus, we enter a process in which faith gives birth to a beautiful life. Do not lose heart in the process—overcome through faith."),
     ('p', "Balancing the whole Bible rather than taking verses out of context is the root and core of faith. The faith of Christ requires faith, and at the same time faith must be accompanied by the works that faith produces."),
     ('v', "圣经 · 罗马书 6:15", "What then? Shall we sin because we are not under the law but under grace? By no means!"),
     ('v', "圣经 · 彼得后书 2:20-22", "If they have escaped the corruption of the world by knowing our Lord and Savior Jesus Christ and are again entangled in it and are overcome, they are worse off at the end than at the beginning. It would have been better for them not to have known the way of righteousness than to have known it and then to turn from the sacred command that was passed on to them. Of them the proverbs are true: “A dog returns to its vomit,” and, “A sow that is washed returns to her wallowing in the mud.”"),
     ('v', "圣经 · 雅各书 2:20-22", "You foolish person, do you want evidence that faith without works is useless? Was not our father Abraham considered righteous for what he did when he offered his son Isaac on the altar? You see that his faith and his actions were working together, and his faith was made complete by his works."),
   ]},
 'question': {
   'title': 'Reflection · Closing',
   'blocks': [
     ('p', "After we believe in Jesus, we will certainly have imperfect behavior or places of weakness. But weakness or imperfection cannot become our excuse to merely declare our faith. Instead, we set a resolution that begins with faith: Jesus' cross has already borne my sins, and from now on I can live a life that is no longer bound by sin."),
     ('p', "When we set our hearts to follow Jesus, I believe sin can no longer bind us. If we think that as long as we believe, even sinning does not matter, we will sink in sin."),
     ('p', "I am justified and saved through faith—and not only saved by faith, but because faith gives birth to saving works, our faith shows that we are truly saved. We must not only let Jesus be our Savior; Jesus is also the Lord of our lives, our King! Amen!"),
     ('q', "Are you willing to let Jesus be not only your Savior but also the Lord of your life? In which areas of your life do you still want to be in charge yourself?\nHow do you understand the relationship between “justification by faith” and “faith producing works”? Is faith without works dead?\nThe Great Commission is not only about preaching the gospel but about making disciples. Are you willing to pay the cost to follow Jesus as a disciple?"),
   ]},
}


def main():
    d = json.load(open(APPDATA, encoding='utf-8'))
    target = None
    for s in d['sermons']['list']:
        if '救主' in s['title']['zh']:
            target = s
            break
    if target is None:
        print('未找到《救主》篇')
        return
    filled = 0
    for ch in target['body']:
        if ch['id'] in EN:
            patch = EN[ch['id']]
            ch['title']['en'] = patch['title']
            vlist = [x for x in patch['blocks'] if x[0] == 'v']
            qlist = [x for x in patch['blocks'] if x[0] == 'q']
            pidx = 0
            vi = 0
            qi = 0
            for b in ch['blocks']:
                if b['type'] == 'p' and pidx < len(patch['blocks']):
                    bt = patch['blocks'][pidx]
                    if bt[0] == 'p':
                        b['en'] = bt[1]
                        filled += 1
                    pidx += 1
                elif b['type'] == 'verse' and vi < len(vlist):
                    _, vlabel, vtext = vlist[vi]
                    b['en']['label'] = vlabel
                    b['en']['text'] = vtext
                    vi += 1
                elif b['type'] == 'question' and qi < len(qlist):
                    b['en'] = qlist[qi][1]
                    qi += 1
    json.dump(d, open(APPDATA, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print('已填充章节:', [ch['id'] for ch in target['body']
                        if ch['id'] in EN and ch['title']['en']])
    print('blocks 填充数:', filled)


if __name__ == '__main__':
    main()
