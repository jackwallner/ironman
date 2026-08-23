#!/usr/bin/env python3
"""Generate the complete App Store metadata set for every supported locale."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
METADATA = ROOT / "fastlane" / "metadata"

LOCALES = [
    "ar-SA", "bn-BD", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA",
    "en-GB", "en-US", "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "gu-IN",
    "he", "hi", "hr", "hu", "id", "it", "ja", "kn-IN", "ko", "ml-IN",
    "mr-IN", "ms", "nl-NL", "no", "or-IN", "pa-IN", "pl", "pt-BR", "pt-PT",
    "ro", "ru", "sk", "sl-SI", "sv", "ta-IN", "te-IN", "th", "tr", "uk",
    "ur-PK", "vi", "zh-Hans", "zh-Hant",
]

URLS = {
    "privacy_url": "https://jackwallner.github.io/ironman/privacy-policy.html",
    "support_url": "https://jackwallner.github.io/ironman/support.html",
    "marketing_url": "https://jackwallner.github.io/ironman/",
}

ENGLISH = {
    "name": "IM Iron Splits: Race Results",
    "subtitle": "Your race splits, ranked",
    "keywords": "triathlon,race results,splits,swim,bike,run,bib,finish,personal best,race history,rankings",
    "description": """Every race you have finished, in one place, ranked the way you think about it.

Type your name once. IM Iron Splits finds your published results and fills your locker with swim, T1, bike, T2 and run splits, bib numbers, age-group places and overall ranks.

YOUR SPLITS, RANKED
See races ranked by swim, bike, run, transitions or finish time. Personal bests are marked on every leg, and full-distance and half-distance races stay in separate comparisons.

WHERE YOU LANDED
See each split against the field that raced it, with the field size and percentile beside the rank.

RACE BOOK
Preview your personal bests and progression by distance. Unlock like-for-like comparisons, time gained or lost by leg, and a polished history you can export as a PDF or image. Race Book is a one-time lifetime purchase with no subscription and no per-export charge.

RACE NOTES
Keep conditions, nutrition and gear attached to the result that produced them.

TRI POINTERS
Browse a coaching clip library organized by race leg.

FREE CORE
Search, claim your results and keep your complete history with full splits, leaderboards, percentiles, notes, race details and the full Pointers library. Your results are never hidden behind a purchase.

Privacy Policy: https://jackwallner.github.io/ironman/privacy-policy.html
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits is independent. It is not affiliated with, endorsed by or sponsored by any race organizer or timing company. Results are shown as published by each event's timer.""",
    "promotional_text": "Type your name once. Every published result loads with full splits, bib numbers and division places.",
    "release_notes": "Find yourself in published race results, then see every split and personal best in one place.",
}


COPY = {
    "ar": {
        "name": "IM Iron Splits: نتائج السباق",
        "subtitle": "رتّب أزمنة سباقك",
        "keywords": "ترياتلون,نتائج السباق,أزمنة السباحة,الدراجة,الجري,رقم الصدر,زمن النهاية,أفضل زمن,سجل السباقات,ترتيب الفئة",
        "description": """كل سباق أنهيته في مكان واحد، مرتب بالطريقة التي تفكر بها في أدائك.

اكتب اسمك مرة واحدة ليعثر IM Iron Splits على نتائجك المنشورة ويعرض أزمنة السباحة والانتقال والدراجة والجري، مع أرقام الصدر وترتيب الفئة والترتيب العام.

شاهد أفضل أزمنتك، وقارن السباقات من النوع نفسه، واعرف موقع كل زمن بين المشاركين. يتيح Race Book المقارنات والتصدير إلى PDF أو صورة عبر شراء مدى الحياة لمرة واحدة، بلا اشتراك أو رسوم تصدير.

تظل الوظائف الأساسية مجانية: البحث، سجل السباقات الكامل، الأزمنة، الترتيبات، الملاحظات ومكتبة Pointers.

سياسة الخصوصية: https://jackwallner.github.io/ironman/privacy-policy.html
شروط الاستخدام: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits تطبيق مستقل غير تابع لأي منظم سباقات أو شركة توقيت.""",
        "promotional_text": "اكتب اسمك مرة واحدة وشاهد كل نتائجك المنشورة مع الأزمنة والترتيبات.",
        "release_notes": "اعثر على نتائجك المنشورة وشاهد كل زمن وأفضل أداء في مكان واحد.",
    },
    "bn": {
        "name": "IM Iron Splits: রেস ফল",
        "subtitle": "রেসের স্প্লিট সাজান",
        "keywords": "ট্রায়াথলন,রেস ফল,স্প্লিট,সাঁতার,বাইক,দৌড়,বিব নম্বর,ফিনিশ টাইম,ব্যক্তিগত সেরা,রেস ইতিহাস",
        "description": """আপনার শেষ করা প্রতিটি রেস এক জায়গায়, আপনার প্রয়োজনের মতো সাজানো।

একবার নাম লিখুন। IM Iron Splits প্রকাশিত ফলাফল খুঁজে সাঁতার, ট্রানজিশন, বাইক ও দৌড়ের স্প্লিট, বিব নম্বর এবং বিভাগ ও সামগ্রিক র‍্যাঙ্ক দেখায়।

ব্যক্তিগত সেরা দেখুন, একই ধরনের রেস তুলনা করুন এবং মাঠের মধ্যে প্রতিটি সময়ের অবস্থান বুঝুন। Race Book একবারের আজীবন কেনাকাটায় তুলনা ও PDF বা ছবি এক্সপোর্ট দেয়, কোনো সাবস্ক্রিপশন বা প্রতি এক্সপোর্টে চার্জ নেই।

বেসিক সুবিধা বিনামূল্যে থাকে: সার্চ, সম্পূর্ণ রেস ইতিহাস, স্প্লিট, র‍্যাঙ্ক, নোট এবং Pointers লাইব্রেরি।

গোপনীয়তা: https://jackwallner.github.io/ironman/privacy-policy.html
ব্যবহারের শর্ত: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits স্বাধীন অ্যাপ, কোনো রেস আয়োজক বা টাইমিং কোম্পানির সঙ্গে যুক্ত নয়।""",
        "promotional_text": "একবার নাম লিখুন, প্রকাশিত ফলাফলে আপনার সব স্প্লিট ও র‍্যাঙ্ক দেখুন।",
        "release_notes": "প্রকাশিত রেস ফলাফলে নিজেকে খুঁজে সব স্প্লিট এক জায়গায় দেখুন।",
    },
    "ca": {
        "name": "IM Iron Splits: Resultats",
        "subtitle": "Ordena els teus parcials",
        "keywords": "triatló,resultats,curses,parcials,natació,bici,córrer,dorsal,temps final,millor marca,historial",
        "description": """Cada cursa que has acabat, en un sol lloc i ordenada com realment la vols entendre.

Escriu el teu nom una vegada. IM Iron Splits troba els resultats publicats i mostra els parcials de natació, transicions, bici i cursa, el dorsal i les posicions de categoria i generals.

Consulta les teves millors marques, compara curses del mateix tipus i entén on cau cada temps dins del grup. Race Book desbloqueja comparacions i exportació a PDF o imatge amb una compra única de per vida, sense subscripció ni càrrec per exportació.

La part essencial és gratuïta: cerca, historial complet, parcials, classificacions, notes i la biblioteca Pointers.

Privacitat: https://jackwallner.github.io/ironman/privacy-policy.html
Condicions: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits és independent i no està afiliada a cap organitzador ni empresa de cronometratge.""",
        "promotional_text": "Escriu el teu nom una vegada i guarda tots els teus parcials i resultats publicats.",
        "release_notes": "Troba els teus resultats publicats i consulta cada parcial en un sol lloc.",
    },
    "cs": {
        "name": "IM Iron Splits: Výsledky",
        "subtitle": "Seřaďte své mezičasy",
        "keywords": "triatlon,výsledky,závody,mezičasy,plavání,kolo,běh,startovní číslo,čas,osobní rekord,historie",
        "description": """Každý dokončený závod na jednom místě, seřazený podle toho, co vás skutečně zajímá.

Zadejte jméno jednou. IM Iron Splits najde zveřejněné výsledky a zobrazí mezičasy plavání, depa, kola a běhu, startovní číslo i pořadí v kategorii a celkově.

Prohlédněte si osobní rekordy, porovnávejte závody stejného typu a zjistěte své místo v poli. Race Book odemyká porovnání a export do PDF nebo obrázku jednorázovým doživotním nákupem, bez předplatného a bez poplatku za export.

Základ zůstává zdarma: hledání, celá historie, mezičasy, pořadí, poznámky a knihovna Pointers.

Zásady ochrany soukromí: https://jackwallner.github.io/ironman/privacy-policy.html
Podmínky použití: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits je nezávislá aplikace bez spojení s pořadateli závodů nebo časomírou.""",
        "promotional_text": "Zadejte jméno jednou a mějte všechny zveřejněné výsledky a mezičasy pohromadě.",
        "release_notes": "Najděte své zveřejněné výsledky a prohlédněte si každý mezičas na jednom místě.",
    },
    "da": {
        "name": "IM Iron Splits: Resultater",
        "subtitle": "Dine løbstider sorteret",
        "keywords": "triatlon,løbsresultater,split,svømning,cykling,løb,startnummer,sluttid,personlig rekord,løbshistorik",
        "description": """Alle løb, du har gennemført, samlet ét sted og sorteret efter det, du faktisk vil vide.

Skriv dit navn én gang. IM Iron Splits finder dine offentliggjorte resultater og viser tider for svømning, skiftezoner, cykling og løb samt startnummer og placeringer.

Se personlige rekorder, sammenlign løb af samme type og forstå din placering i feltet. Race Book låser sammenligning og eksport til PDF eller billede op med et engangskøb for livstid, uden abonnement eller gebyr pr. eksport.

Kernen er gratis: søgning, fuld historik, tider, placeringer, noter og Pointers-biblioteket.

Privatliv: https://jackwallner.github.io/ironman/privacy-policy.html
Vilkår: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits er en uafhængig app uden tilknytning til løbsarrangører eller tidtagningsfirmaer.""",
        "promotional_text": "Skriv dit navn én gang og saml alle offentliggjorte resultater og split-tider.",
        "release_notes": "Find dine offentliggjorte resultater og se alle split-tider samlet.",
    },
    "de": {
        "name": "IM Iron Splits: Rennergebnis",
        "subtitle": "Deine Rennzeiten sortiert",
        "keywords": "Triathlon,Rennresultate,Zwischenzeiten,Schwimmen,Radfahren,Laufen,Startnummer,Endzeit,Bestzeit,Rennhistorie",
        "description": """Jedes Rennen, das du beendet hast, an einem Ort und so sortiert, wie du deine Leistung wirklich betrachtest.

Gib deinen Namen einmal ein. IM Iron Splits findet veröffentlichte Ergebnisse und zeigt Schwimm-, Wechsel-, Rad- und Laufzeiten, Startnummern sowie Platzierungen in Altersklasse und Gesamtfeld.

Sieh deine Bestzeiten, vergleiche Rennen derselben Distanz und ordne jede Zeit im Feld ein. Race Book schaltet Vergleiche und PDF- oder Bildexport mit einem einmaligen Kauf auf Lebenszeit frei, ohne Abo und ohne Gebühr pro Export.

Der Kern bleibt kostenlos: Suche, vollständige Historie, Zwischenzeiten, Ranglisten, Notizen und die Pointers-Bibliothek.

Datenschutz: https://jackwallner.github.io/ironman/privacy-policy.html
Nutzungsbedingungen: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ist unabhängig und nicht mit Rennveranstaltern oder Zeitmessern verbunden.""",
        "promotional_text": "Gib deinen Namen einmal ein und sammle alle veröffentlichten Zeiten und Platzierungen.",
        "release_notes": "Finde deine veröffentlichten Ergebnisse und sieh jede Zwischenzeit an einem Ort.",
    },
    "el": {
        "name": "IM Iron Splits: Αποτελέσματα",
        "subtitle": "Τα splits των αγώνων σου",
        "keywords": "τρίαθλο,αποτελέσματα αγώνων,splits,κολύμβηση,ποδήλατο,τρέξιμο,αριθμός,τερματισμός,ρεκόρ,ιστορικό",
        "description": """Κάθε αγώνας που ολοκλήρωσες, σε ένα μέρος και ταξινομημένος όπως θέλεις να τον καταλάβεις.

Γράψε το όνομά σου μία φορά. Το IM Iron Splits βρίσκει τα δημοσιευμένα αποτελέσματά σου και εμφανίζει κολύμβηση, αλλαγές, ποδήλατο, τρέξιμο, αριθμό συμμετοχής και κατατάξεις.

Δες τα προσωπικά σου ρεκόρ, σύγκρινε αγώνες ίδιου τύπου και κατάλαβε τη θέση κάθε χρόνου στο πεδίο. Το Race Book ξεκλειδώνει συγκρίσεις και εξαγωγή PDF ή εικόνας με μία εφάπαξ αγορά εφ' όρου ζωής, χωρίς συνδρομή ή χρέωση ανά εξαγωγή.

Ο βασικός κορμός παραμένει δωρεάν: αναζήτηση, πλήρες ιστορικό, splits, κατατάξεις, σημειώσεις και βιβλιοθήκη Pointers.

Απόρρητο: https://jackwallner.github.io/ironman/privacy-policy.html
Όροι χρήσης: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Το IM Iron Splits είναι ανεξάρτητη εφαρμογή χωρίς σχέση με διοργανωτές ή εταιρείες χρονομέτρησης.""",
        "promotional_text": "Γράψε το όνομά σου μία φορά και δες όλα τα δημοσιευμένα splits και αποτελέσματά σου.",
        "release_notes": "Βρες τα δημοσιευμένα αποτελέσματά σου και δες κάθε split σε ένα μέρος.",
    },
    "es": {
        "name": "IM Iron Splits: Resultados",
        "subtitle": "Tus parciales, ordenados",
        "keywords": "triatlón,resultados,carreras,parciales,natación,bici,correr,dorsal,tiempo final,mejor marca,historial",
        "description": """Cada carrera que has terminado, en un solo lugar y ordenada como realmente quieres entenderla.

Escribe tu nombre una vez. IM Iron Splits encuentra tus resultados publicados y muestra los parciales de natación, transiciones, bici y carrera, el dorsal y tus puestos de categoría y generales.

Consulta tus mejores marcas, compara carreras del mismo tipo y entiende dónde cae cada tiempo dentro del grupo. Race Book desbloquea comparaciones y exportación a PDF o imagen con una compra única de por vida, sin suscripción ni cobro por exportación.

La parte esencial es gratis: búsqueda, historial completo, parciales, clasificaciones, notas y la biblioteca Pointers.

Privacidad: https://jackwallner.github.io/ironman/privacy-policy.html
Condiciones: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits es independiente y no está afiliada a organizadores de carreras ni empresas de cronometraje.""",
        "promotional_text": "Escribe tu nombre una vez y guarda todos tus resultados publicados, parciales y puestos.",
        "release_notes": "Encuentra tus resultados publicados y consulta cada parcial en un solo lugar.",
    },
    "fi": {
        "name": "IM Iron Splits: Tulokset",
        "subtitle": "Lajiesi ajat järjestyksessä",
        "keywords": "triathlon,kilpailutulokset,osat, uinti,pyöräily,juoksu,numero,loppuaika,ennätys,kilpailuhistoria",
        "description": """Jokainen suorittamasi kilpailu yhdessä paikassa, järjestettynä tavalla, jolla haluat ymmärtää suoritustasi.

Kirjoita nimesi kerran. IM Iron Splits löytää julkaistut tuloksesi ja näyttää uinnin, vaihdot, pyöräilyn ja juoksun ajat sekä kilpailunumeron ja sijoitukset.

Näe omat ennätyksesi, vertaa samanlaisia kilpailuja ja ymmärrä aikasi paikka kentässä. Race Book avaa vertailut ja PDF- tai kuvaviennin yhdellä elinikäisellä kertamaksulla, ilman tilausta tai vientimaksua.

Ydin on ilmainen: haku, koko historia, osat, sijoitukset, muistiinpanot ja Pointers-kirjasto.

Tietosuoja: https://jackwallner.github.io/ironman/privacy-policy.html
Käyttöehdot: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits on riippumaton eikä liity kilpailujärjestäjiin tai ajanottoyrityksiin.""",
        "promotional_text": "Kirjoita nimesi kerran ja pidä kaikki julkaistut kilpailuajat yhdessä paikassa.",
        "release_notes": "Löydä julkaistut tuloksesi ja katso jokainen osuus yhdessä paikassa.",
    },
    "fr": {
        "name": "IM Iron Splits: Résultats",
        "subtitle": "Tes temps, classés",
        "keywords": "triathlon,résultats,course,temps intermédiaires,natation,vélo,course à pied,dossard,temps final,record,historique",
        "description": """Toutes les courses que tu as terminées, au même endroit et classées selon ce que tu veux vraiment comprendre.

Saisis ton nom une fois. IM Iron Splits retrouve tes résultats publiés et affiche les temps de natation, transitions, vélo et course, ton dossard et tes classements.

Vois tes meilleures performances, compare les courses du même type et comprends la place de chaque temps dans le peloton. Race Book déverrouille les comparaisons et l'export PDF ou image avec un achat unique à vie, sans abonnement ni frais par export.

Le cœur reste gratuit : recherche, historique complet, temps intermédiaires, classements, notes et bibliothèque Pointers.

Confidentialité : https://jackwallner.github.io/ironman/privacy-policy.html
Conditions : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits est indépendant et n'est affilié à aucun organisateur ni chronométreur.""",
        "promotional_text": "Saisis ton nom une fois et retrouve tous tes résultats, temps et classements publiés.",
        "release_notes": "Retrouve tes résultats publiés et consulte chaque temps au même endroit.",
    },
    "gu": {
        "name": "IM Iron Splits: રેસ પરિણામ",
        "subtitle": "તમારા સ્પ્લિટ્સ ક્રમમાં",
        "keywords": "ટ્રાયથલોન,રેસ પરિણામ,સ્પ્લિટ્સ,સ્વિમિંગ,બાઇક,દોડ,બિબ નંબર,ફિનિશ સમય,બેસ્ટ,રેસ ઇતિહાસ",
        "description": """તમે પૂર્ણ કરેલી દરેક રેસ એક જ જગ્યાએ, તમારા પ્રદર્શનને સમજવા માટે યોગ્ય રીતે ગોઠવેલી.

તમારું નામ એક વાર લખો. IM Iron Splits પ્રકાશિત પરિણામો શોધી સ્વિમિંગ, ટ્રાન્ઝિશન, બાઇક અને રન સ્પ્લિટ્સ, બિબ નંબર તથા રેન્ક બતાવે છે.

વ્યક્તિગત બેસ્ટ જુઓ અને સમાન પ્રકારની રેસ સરખાવો. Race Book એક વખતની આજીવન ખરીદીથી સરખામણી અને PDF અથવા ઇમેજ નિકાસ ખોલે છે, કોઈ સબ્સ્ક્રિપ્શન કે નિકાસ ચાર્જ વિના.

મુખ્ય સુવિધાઓ મફત રહે છે: શોધ, સંપૂર્ણ ઇતિહાસ, સ્પ્લિટ્સ, રેન્ક, નોંધો અને Pointers લાઇબ્રેરી.

ગોપનીયતા: https://jackwallner.github.io/ironman/privacy-policy.html
ઉપયોગની શરતો: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits સ્વતંત્ર એપ છે અને કોઈ રેસ આયોજક અથવા ટાઇમિંગ કંપની સાથે જોડાયેલી નથી.""",
        "promotional_text": "નામ એક વાર લખો અને તમારા બધા પ્રકાશિત સ્પ્લિટ્સ અને પરિણામો મેળવો.",
        "release_notes": "તમારા પ્રકાશિત પરિણામો શોધો અને દરેક સ્પ્લિટ એક જ જગ્યાએ જુઓ.",
    },
    "he": {
        "name": "IM Iron Splits: תוצאות",
        "subtitle": "הפיצולים שלך, מדורגים",
        "keywords": "טריאתלון,תוצאות מרוץ,פיצולים,שחייה,אופניים,ריצה,מספר חזה,זמן סיום,שיא אישי,היסטוריה",
        "description": """כל מרוץ שסיימת, במקום אחד ובסדר שעוזר לך להבין את הביצוע.

הקלד את שמך פעם אחת. IM Iron Splits מוצאת תוצאות שפורסמו ומציגה זמני שחייה, מעברים, אופניים וריצה, מספר חזה ודירוגים.

ראה שיאים אישיים, השווה מרוצים מאותו סוג והבן את המקום של כל זמן בשדה. Race Book פותחת השוואות וייצוא ל‑PDF או לתמונה ברכישה חד־פעמית לכל החיים, ללא מנוי וללא חיוב על ייצוא.

הליבה נשארת חינמית: חיפוש, היסטוריה מלאה, פיצולים, דירוגים, הערות וספריית Pointers.

פרטיות: https://jackwallner.github.io/ironman/privacy-policy.html
תנאי שימוש: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits היא אפליקציה עצמאית ואינה קשורה למארגני מרוצים או לחברות מדידת זמן.""",
        "promotional_text": "הקלד את שמך פעם אחת ושמור את כל התוצאות והפיצולים שפורסמו.",
        "release_notes": "מצא את התוצאות שפורסמו וראה כל פיצול במקום אחד.",
    },
    "hi": {
        "name": "IM Iron Splits: रेस नतीजे",
        "subtitle": "अपने स्प्लिट्स क्रम में देखें",
        "keywords": "ट्रायथलॉन,रेस नतीजे,स्प्लिट्स,तैराकी,साइकिल,दौड़,बिब नंबर,फिनिश टाइम,बेस्ट टाइम,रेस इतिहास",
        "description": """आपने जो हर रेस पूरी की है, वह एक ही जगह पर और आपके प्रदर्शन को समझने के लिए सही क्रम में।

अपना नाम एक बार लिखें। IM Iron Splits प्रकाशित नतीजे खोजकर तैराकी, ट्रांज़िशन, साइकिल और रन स्प्लिट्स, बिब नंबर और रैंक दिखाता है।

अपने व्यक्तिगत बेस्ट देखें और एक जैसी रेस की तुलना करें। Race Book एक बार की आजीवन खरीद से तुलना और PDF या इमेज एक्सपोर्ट खोलता है, बिना सब्सक्रिप्शन या प्रति एक्सपोर्ट शुल्क के।

मुख्य सुविधाएं मुफ्त रहती हैं: खोज, पूरा इतिहास, स्प्लिट्स, रैंक, नोट्स और Pointers लाइब्रेरी।

गोपनीयता: https://jackwallner.github.io/ironman/privacy-policy.html
उपयोग की शर्तें: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits स्वतंत्र ऐप है और किसी रेस आयोजक या टाइमिंग कंपनी से संबद्ध नहीं है।""",
        "promotional_text": "नाम एक बार लिखें और अपने सभी प्रकाशित स्प्लिट्स, नतीजे और रैंक देखें।",
        "release_notes": "अपने प्रकाशित रेस नतीजे खोजें और हर स्प्लिट एक जगह देखें।",
    },
    "hr": {
        "name": "IM Iron Splits: Rezultati",
        "subtitle": "Tvoja vremena, poredana",
        "keywords": "triatlon,rezultati utrka,međuvremena,plivanje,bicikl,trčanje,startni broj,završno vrijeme,rekord,povijest",
        "description": """Svaka utrka koju si završio na jednom mjestu, poredana prema onome što želiš razumjeti.

Upiši ime jednom. IM Iron Splits pronalazi objavljene rezultate i prikazuje vremena plivanja, izmjena, bicikla i trčanja, startni broj te plasmane.

Pogledaj osobne rekorde, usporedi utrke iste vrste i vidi mjesto svakog vremena u poretku. Race Book otključava usporedbe i izvoz u PDF ili sliku jednokratnom doživotnom kupnjom, bez pretplate i bez naplate izvoza.

Osnovne značajke ostaju besplatne: pretraživanje, cijela povijest, vremena, plasmani, bilješke i knjižnica Pointers.

Privatnost: https://jackwallner.github.io/ironman/privacy-policy.html
Uvjeti: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits je neovisna aplikacija bez veze s organizatorima utrka ili tvrtkama za mjerenje vremena.""",
        "promotional_text": "Upiši ime jednom i sačuvaj sve objavljene rezultate, vremena i plasmane.",
        "release_notes": "Pronađi objavljene rezultate i pogledaj svako međuvrijeme na jednom mjestu.",
    },
    "hu": {
        "name": "IM Iron Splits: Eredmények",
        "subtitle": "Versenyidők rangsorolva",
        "keywords": "triatlon,versenyeredmények,részidők,úszás,kerékpár,futás,rajtszám,nettó idő,csúcs,versenynapló",
        "description": """Minden teljesített versenyed egy helyen, úgy rendezve, ahogy valóban értelmezni szeretnéd.

Írd be egyszer a neved. Az IM Iron Splits megkeresi a közzétett eredményeidet, és megmutatja az úszás, depó, kerékpár és futás részideit, a rajtszámot, valamint a helyezéseket.

Nézd meg az egyéni csúcsokat, hasonlítsd össze az azonos típusú versenyeket, és lásd, hol állsz a mezőnyben. A Race Book egyszeri, élethosszig tartó vásárlással nyitja meg az összehasonlítást és a PDF- vagy képexportot, előfizetés és exportdíj nélkül.

Az alap ingyenes: keresés, teljes előzmény, részidők, helyezések, jegyzetek és a Pointers könyvtár.

Adatvédelem: https://jackwallner.github.io/ironman/privacy-policy.html
Felhasználási feltételek: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Az IM Iron Splits független alkalmazás, nem kapcsolódik versenyszervezőkhöz vagy időmérő cégekhez.""",
        "promotional_text": "Írd be egyszer a neved, és gyűjtsd egy helyre minden közzétett eredményedet.",
        "release_notes": "Találd meg közzétett eredményeidet, és nézd meg minden részidődet egy helyen.",
    },
    "id": {
        "name": "IM Iron Splits: Hasil Lomba",
        "subtitle": "Split lombamu, tersusun",
        "keywords": "triathlon,hasil lomba,split,renang,sepeda,lari,nomor dada,waktu finis,terbaik,riwayat lomba",
        "description": """Semua lomba yang kamu selesaikan, tersimpan di satu tempat dan disusun untuk membantu memahami performamu.

Masukkan namamu sekali. IM Iron Splits menemukan hasil yang dipublikasikan dan menampilkan split renang, transisi, sepeda, dan lari, nomor dada, serta peringkat.

Lihat catatan waktu terbaik, bandingkan lomba sejenis, dan pahami posisi setiap waktu di antara peserta. Race Book membuka perbandingan serta ekspor PDF atau gambar dengan pembelian satu kali seumur hidup, tanpa langganan dan tanpa biaya per ekspor.

Fitur inti tetap gratis: pencarian, riwayat lengkap, split, peringkat, catatan, dan pustaka Pointers.

Privasi: https://jackwallner.github.io/ironman/privacy-policy.html
Ketentuan: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits adalah aplikasi independen dan tidak berafiliasi dengan penyelenggara lomba atau perusahaan pencatat waktu.""",
        "promotional_text": "Masukkan namamu sekali dan kumpulkan semua hasil, split, serta peringkat yang dipublikasikan.",
        "release_notes": "Temukan hasil lomba yang dipublikasikan dan lihat semua split di satu tempat.",
    },
    "it": {
        "name": "IM Iron Splits: Risultati",
        "subtitle": "I tuoi tempi, classificati",
        "keywords": "triathlon,risultati gara,split,nuoto,bici,corsa,pettorale,tempo finale,record,storico gare",
        "description": """Ogni gara che hai concluso, in un unico posto e ordinata nel modo in cui vuoi davvero capirla.

Inserisci il tuo nome una volta. IM Iron Splits trova i risultati pubblicati e mostra i tempi di nuoto, transizioni, bici e corsa, il pettorale e le classifiche.

Scopri i tuoi record personali, confronta gare dello stesso tipo e capisci la posizione di ogni tempo nel gruppo. Race Book sblocca confronti ed esportazione PDF o immagine con un acquisto unico a vita, senza abbonamento né costi per esportazione.

Il nucleo resta gratuito: ricerca, storico completo, split, classifiche, note e libreria Pointers.

Privacy: https://jackwallner.github.io/ironman/privacy-policy.html
Termini: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits è indipendente e non è affiliata a organizzatori di gare o società di cronometraggio.""",
        "promotional_text": "Inserisci il tuo nome una volta e raccogli risultati, split e classifiche pubblicati.",
        "release_notes": "Trova i tuoi risultati pubblicati e consulta ogni split in un unico posto.",
    },
    "ja": {
        "name": "IM Iron Splits: レース結果",
        "subtitle": "レースの区間を順位で確認",
        "keywords": "トライアスロン,レース結果,スプリット,スイム,バイク,ラン,ゼッケン,完走タイム,自己ベスト,履歴",
        "description": """完走したすべてのレースを、パフォーマンスを理解しやすい形でまとめます。

名前を一度入力するだけ。IM Iron Splits が公開結果を見つけ、スイム、トランジション、バイク、ランの区間タイム、ゼッケン、順位を表示します。

自己ベストを確認し、同じ種類のレースを比較し、フィールドの中で各タイムがどこにあるかを把握できます。Race Book は一度の買い切りで比較と PDF または画像への書き出しを解放します。サブスクリプションも書き出しごとの料金もありません。

検索、全履歴、区間、順位、メモ、Pointers ライブラリは無料です。

プライバシー: https://jackwallner.github.io/ironman/privacy-policy.html
利用規約: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits は独立したアプリで、レース主催者や計時会社とは関係ありません。""",
        "promotional_text": "名前を一度入力して、公開された結果とすべての区間タイムをまとめます。",
        "release_notes": "公開されたレース結果を見つけ、すべての区間タイムを確認できます。",
    },
    "kn": {
        "name": "IM Iron Splits: ರೇಸ್ ಫಲಿತಾಂಶ",
        "subtitle": "ನಿಮ್ಮ ಸ್ಪ್ಲಿಟ್‌ಗಳನ್ನು ಕ್ರಮಿಸಿ",
        "keywords": "ಟ್ರಯಥ್ಲಾನ್,ರೇಸ್ ಫಲಿತಾಂಶ,ಸ್ಪ್ಲಿಟ್,ಈಜು,ಬೈಕ್,ಓಟ,ಬಿಬ್ ಸಂಖ್ಯೆ,ಫಿನಿಶ್ ಸಮಯ,ಅತ್ಯುತ್ತಮ,ಇತಿಹಾಸ",
        "description": """ನೀವು ಪೂರ್ಣಗೊಳಿಸಿದ ಪ್ರತಿಯೊಂದು ರೇಸ್ ಒಂದೇ ಸ್ಥಳದಲ್ಲಿ, ನಿಮ್ಮ ಪ್ರದರ್ಶನವನ್ನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲು ಸರಿಯಾದ ಕ್ರಮದಲ್ಲಿ.

ನಿಮ್ಮ ಹೆಸರನ್ನು ಒಮ್ಮೆ ನಮೂದಿಸಿ. IM Iron Splits ಪ್ರಕಟಿತ ಫಲಿತಾಂಶಗಳನ್ನು ಹುಡುಕಿ ಈಜು, ಟ್ರಾನ್ಸಿಷನ್, ಬೈಕ್ ಮತ್ತು ಓಟದ ಸ್ಪ್ಲಿಟ್‌ಗಳು, ಬಿಬ್ ಸಂಖ್ಯೆ ಮತ್ತು ಶ್ರೇಣಿಗಳನ್ನು ತೋರಿಸುತ್ತದೆ.

ವೈಯಕ್ತಿಕ ಅತ್ಯುತ್ತಮಗಳನ್ನು ನೋಡಿ ಮತ್ತು ಒಂದೇ ರೀತಿಯ ರೇಸ್‌ಗಳನ್ನು ಹೋಲಿಸಿ. Race Book ಒಂದು ಬಾರಿ ಜೀವಮಾನ ಖರೀದಿಯಿಂದ ಹೋಲಿಕೆ ಮತ್ತು PDF ಅಥವಾ ಚಿತ್ರ ರಫ್ತು ತೆರೆಯುತ್ತದೆ, ಚಂದಾದಾರಿಕೆ ಅಥವಾ ಪ್ರತಿ ರಫ್ತಿಗೆ ಶುಲ್ಕವಿಲ್ಲ.

ಮೂಲ ಸೌಲಭ್ಯಗಳು ಉಚಿತ: ಹುಡುಕಾಟ, ಸಂಪೂರ್ಣ ಇತಿಹಾಸ, ಸ್ಪ್ಲಿಟ್‌ಗಳು, ಶ್ರೇಣಿಗಳು, ಟಿಪ್ಪಣಿಗಳು ಮತ್ತು Pointers ಲೈಬ್ರರಿ.

ಗೌಪ್ಯತೆ: https://jackwallner.github.io/ironman/privacy-policy.html
ಬಳಕೆಯ ನಿಯಮಗಳು: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ಸ್ವತಂತ್ರ ಅಪ್ಲಿಕೇಶನ್ ಆಗಿದ್ದು ಯಾವುದೇ ರೇಸ್ ಆಯೋಜಕ ಅಥವಾ ಟೈಮಿಂಗ್ ಕಂಪನಿಯೊಂದಿಗೆ ಸಂಬಂಧ ಹೊಂದಿಲ್ಲ.""",
        "promotional_text": "ಹೆಸರನ್ನು ಒಮ್ಮೆ ನಮೂದಿಸಿ, ಪ್ರಕಟಿತ ಫಲಿತಾಂಶಗಳು ಮತ್ತು ಎಲ್ಲಾ ಸ್ಪ್ಲಿಟ್‌ಗಳನ್ನು ಪಡೆಯಿರಿ.",
        "release_notes": "ನಿಮ್ಮ ಪ್ರಕಟಿತ ರೇಸ್ ಫಲಿತಾಂಶಗಳನ್ನು ಹುಡುಕಿ ಮತ್ತು ಪ್ರತಿಯೊಂದು ಸ್ಪ್ಲಿಟ್ ಅನ್ನು ಒಂದೇ ಸ್ಥಳದಲ್ಲಿ ನೋಡಿ.",
    },
    "ko": {
        "name": "IM Iron Splits: 레이스 결과",
        "subtitle": "레이스 구간을 순위로 확인",
        "keywords": "트라이애슬론,레이스 결과,스플릿,수영,자전거,달리기,배번,완주 시간,개인 기록,레이스 기록",
        "description": """완주한 모든 레이스를 한곳에 모아, 기록을 이해하기 쉽게 정리합니다.

이름을 한 번 입력하세요. IM Iron Splits가 공개된 결과를 찾아 수영, 트랜지션, 자전거, 달리기 구간 기록과 배번, 순위를 보여줍니다.

개인 최고 기록을 확인하고 같은 유형의 레이스를 비교하며 필드 안에서 각 기록의 위치를 파악하세요. Race Book은 한 번의 평생 구매로 비교와 PDF 또는 이미지 내보내기를 잠금 해제합니다. 구독과 내보내기별 요금은 없습니다.

검색, 전체 기록, 구간, 순위, 메모, Pointers 라이브러리는 무료입니다.

개인정보 보호: https://jackwallner.github.io/ironman/privacy-policy.html
이용 약관: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits는 독립 앱이며 레이스 주최자나 기록 측정 회사와 제휴하지 않습니다.""",
        "promotional_text": "이름을 한 번 입력하고 공개된 결과와 모든 구간 기록을 모아보세요.",
        "release_notes": "공개된 레이스 결과를 찾고 모든 구간 기록을 한곳에서 확인하세요.",
    },
    "ml": {
        "name": "IM Iron Splits: റേസ് ഫലം",
        "subtitle": "സ്പ്ലിറ്റുകൾ ക്രമത്തിൽ",
        "keywords": "ട്രയാത്ലൺ,റേസ് ഫലം,സ്പ്ലിറ്റ്,നീന്തൽ,ബൈക്ക്,ഓട്ടം,ബിബ് നമ്പർ,ഫിനിഷ് സമയം,മികച്ച സമയം,ചരിത്രം",
        "description": """നിങ്ങൾ പൂർത്തിയാക്കിയ എല്ലാ റേസുകളും ഒരിടത്ത്, നിങ്ങളുടെ പ്രകടനം മനസ്സിലാക്കാൻ എളുപ്പമായി ക്രമീകരിച്ചിരിക്കുന്നു.

നിങ്ങളുടെ പേര് ഒരിക്കൽ നൽകുക. IM Iron Splits പ്രസിദ്ധീകരിച്ച ഫലങ്ങൾ കണ്ടെത്തി നീന്തൽ, ട്രാൻസിഷൻ, ബൈക്ക്, ഓട്ടം സ്പ്ലിറ്റുകൾ, ബിബ് നമ്പർ, റാങ്കുകൾ എന്നിവ കാണിക്കുന്നു.

വ്യക്തിഗത മികച്ച സമയം കാണുകയും ഒരേ തരത്തിലുള്ള റേസുകൾ താരതമ്യം ചെയ്യുകയും ചെയ്യുക. Race Book ഒറ്റത്തവണയുള്ള ആജീവനാന്ത വാങ്ങലിലൂടെ താരതമ്യവും PDF അല്ലെങ്കിൽ ചിത്രം എക്സ്പോർട്ടും തുറക്കുന്നു, സബ്സ്ക്രിപ്ഷനും ഓരോ എക്സ്പോർട്ടിനും ഫീസും ഇല്ല.

അടിസ്ഥാന സൗകര്യങ്ങൾ സൗജന്യമാണ്: തിരച്ചിൽ, പൂർണ്ണ ചരിത്രം, സ്പ്ലിറ്റുകൾ, റാങ്കുകൾ, കുറിപ്പുകൾ, Pointers ലൈബ്രറി.

സ്വകാര്യത: https://jackwallner.github.io/ironman/privacy-policy.html
ഉപയോഗ നിബന്ധനകൾ: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ഒരു സ്വതന്ത്ര ആപ്പാണ്; റേസ് സംഘാടകരുമായോ ടൈമിംഗ് കമ്പനികളുമായോ ബന്ധമില്ല.""",
        "promotional_text": "പേര് ഒരിക്കൽ നൽകൂ, പ്രസിദ്ധീകരിച്ച എല്ലാ ഫലങ്ങളും സ്പ്ലിറ്റുകളും കാണൂ.",
        "release_notes": "പ്രസിദ്ധീകരിച്ച റേസ് ഫലങ്ങൾ കണ്ടെത്തി എല്ലാ സ്പ്ലിറ്റുകളും ഒരിടത്ത് കാണൂ.",
    },
    "mr": {
        "name": "IM Iron Splits: रेस निकाल",
        "subtitle": "तुमचे स्प्लिट्स क्रमाने पहा",
        "keywords": "ट्रायथलॉन,रेस निकाल,स्प्लिट्स,पोहणे,बाईक,धावणे,बिब नंबर,फिनिश वेळ,वैयक्तिक सर्वोत्तम,रेस इतिहास",
        "description": """तुम्ही पूर्ण केलेली प्रत्येक रेस एकाच ठिकाणी, तुमची कामगिरी समजून घेण्यासाठी योग्य क्रमात.

तुमचे नाव एकदा लिहा. IM Iron Splits प्रकाशित निकाल शोधून पोहणे, ट्रान्झिशन, बाईक आणि रन स्प्लिट्स, बिब नंबर आणि क्रमांक दाखवते.

वैयक्तिक सर्वोत्तम वेळा पहा आणि समान प्रकारच्या रेसची तुलना करा. Race Book एकदाच केलेल्या आजीवन खरेदीने तुलना आणि PDF किंवा इमेज एक्सपोर्ट उघडते, सबस्क्रिप्शन किंवा प्रत्येक एक्सपोर्टचे शुल्क नाही.

मुख्य सुविधा मोफत आहेत: शोध, पूर्ण इतिहास, स्प्लिट्स, क्रमांक, नोंदी आणि Pointers लायब्ररी.

गोपनीयता: https://jackwallner.github.io/ironman/privacy-policy.html
वापराच्या अटी: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits स्वतंत्र अॅप आहे आणि कोणत्याही रेस आयोजक किंवा टाइमिंग कंपनीशी संबंधित नाही.""",
        "promotional_text": "नाव एकदा लिहा आणि तुमचे सर्व प्रकाशित निकाल, स्प्लिट्स व क्रमांक पहा.",
        "release_notes": "तुमचे प्रकाशित रेस निकाल शोधा आणि प्रत्येक स्प्लिट एकाच ठिकाणी पहा.",
    },
    "ms": {
        "name": "IM Iron Splits: Keputusan",
        "subtitle": "Masa perlumbaan anda disusun",
        "keywords": "triathlon,keputusan perlumbaan,split,renang,basikal,lari,nombor bib,masa tamat,rekod peribadi,sejarah",
        "description": """Setiap perlumbaan yang anda tamatkan, dalam satu tempat dan disusun untuk memahami prestasi anda.

Masukkan nama sekali. IM Iron Splits mencari keputusan yang diterbitkan dan memaparkan split renang, transisi, basikal dan larian, nombor bib serta kedudukan.

Lihat rekod peribadi, bandingkan perlumbaan yang sama jenis dan fahami kedudukan setiap masa dalam medan. Race Book membuka perbandingan dan eksport PDF atau imej dengan pembelian sekali seumur hidup, tanpa langganan atau caj setiap eksport.

Ciri teras kekal percuma: carian, sejarah penuh, split, kedudukan, nota dan pustaka Pointers.

Privasi: https://jackwallner.github.io/ironman/privacy-policy.html
Syarat penggunaan: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ialah aplikasi bebas dan tidak bergabung dengan penganjur perlumbaan atau syarikat pemasaan.""",
        "promotional_text": "Masukkan nama sekali dan kumpulkan semua keputusan, split serta kedudukan yang diterbitkan.",
        "release_notes": "Cari keputusan perlumbaan anda dan lihat setiap split di satu tempat.",
    },
    "nl": {
        "name": "IM Iron Splits: Raceuitslag",
        "subtitle": "Je racetijden gerangschikt",
        "keywords": "triatlon,race resultaten,tussentijden,zwemmen,fietsen,lopen,startnummer,eindtijd,persoonlijk record,racehistorie",
        "description": """Elke race die je hebt voltooid op één plek, gerangschikt op de manier waarop je je prestatie echt wilt begrijpen.

Vul je naam één keer in. IM Iron Splits vindt je gepubliceerde resultaten en toont zwem-, wissel-, fiets- en looptijden, startnummer en klasseringen.

Bekijk persoonlijke records, vergelijk races van hetzelfde type en begrijp waar elke tijd in het veld valt. Race Book ontgrendelt vergelijkingen en export naar PDF of afbeelding met een eenmalige aankoop voor altijd, zonder abonnement of kosten per export.

De basis blijft gratis: zoeken, volledige historie, tussentijden, ranglijsten, notities en de Pointers-bibliotheek.

Privacy: https://jackwallner.github.io/ironman/privacy-policy.html
Voorwaarden: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits is onafhankelijk en niet verbonden aan raceorganisatoren of tijdwaarnemingsbedrijven.""",
        "promotional_text": "Vul je naam één keer in en verzamel al je gepubliceerde tijden, resultaten en klasseringen.",
        "release_notes": "Vind je gepubliceerde resultaten en bekijk elke tussentijd op één plek.",
    },
    "no": {
        "name": "IM Iron Splits: Resultater",
        "subtitle": "Dine løpetider sortert",
        "keywords": "triatlon,løpsresultater,splitter,svømming,sykling,løping,startnummer,sluttid,personlig rekord,løpshistorikk",
        "description": """Alle løpene du har fullført, samlet på ett sted og sortert etter det du faktisk vil forstå.

Skriv inn navnet ditt én gang. IM Iron Splits finner publiserte resultater og viser tider for svømming, vekslingssoner, sykling og løping, startnummer og plasseringer.

Se personlige rekorder, sammenlign løp av samme type og forstå hvor hver tid ligger i feltet. Race Book låser opp sammenligning og eksport til PDF eller bilde med et engangskjøp for livet, uten abonnement eller eksportavgift.

Kjernen er gratis: søk, full historikk, splitter, plasseringer, notater og Pointers-biblioteket.

Personvern: https://jackwallner.github.io/ironman/privacy-policy.html
Vilkår: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits er uavhengig og ikke knyttet til løpsarrangører eller tidtakingsselskaper.""",
        "promotional_text": "Skriv inn navnet ditt én gang og samle alle publiserte resultater og løpetider.",
        "release_notes": "Finn publiserte resultater og se alle splitter samlet på ett sted.",
    },
    "or": {
        "name": "IM Iron Splits: ରେସ ଫଳ",
        "subtitle": "ଆପଣଙ୍କ ସ୍ପ୍ଲିଟ୍ କ୍ରମରେ",
        "keywords": "ଟ୍ରାଏଥଲନ,ରେସ ଫଳ,ସ୍ପ୍ଲିଟ୍,ସନ୍ତରଣ,ବାଇକ,ଦୌଡ,ବିବ ନମ୍ବର,ଫିନିଶ ସମୟ,ଶ୍ରେଷ୍ଠ,ଇତିହାସ",
        "description": """ଆପଣ ସମାପ୍ତ କରିଥିବା ପ୍ରତ୍ୟେକ ରେସ ଏକ ସ୍ଥାନରେ, ଆପଣଙ୍କ ପ୍ରଦର୍ଶନ ବୁଝିବା ପାଇଁ ସହଜ ଭାବରେ।

ଆପଣଙ୍କ ନାମ ଥରେ ଲେଖନ୍ତୁ। IM Iron Splits ପ୍ରକାଶିତ ଫଳ ଖୋଜି ସନ୍ତରଣ, ଟ୍ରାନ୍ସିସନ, ବାଇକ ଓ ଦୌଡର ସ୍ପ୍ଲିଟ୍, ବିବ ନମ୍ବର ଏବଂ ରାଙ୍କ ଦେଖାଏ।

ବ୍ୟକ୍ତିଗତ ଶ୍ରେଷ୍ଠ ଦେଖନ୍ତୁ ଏବଂ ସମାନ ପ୍ରକାର ରେସ ତୁଳନା କରନ୍ତୁ। Race Book ଏକଥରର ଆଜୀବନ କ୍ରୟରେ ତୁଳନା ଓ PDF କିମ୍ବା ଚିତ୍ର ଏକ୍ସପୋର୍ଟ ଖୋଲେ, ସବସ୍କ୍ରିପସନ କିମ୍ବା ପ୍ରତି ଏକ୍ସପୋର୍ଟ ଶୁଳ୍କ ନାହିଁ।

ମୂଳ ସୁବିଧା ମାଗଣା: ସନ୍ଧାନ, ସମ୍ପୂର୍ଣ୍ଣ ଇତିହାସ, ସ୍ପ୍ଲିଟ୍, ରାଙ୍କ, ଟିପ୍ପଣୀ ଏବଂ Pointers ଲାଇବ୍ରେରୀ।

ଗୋପନୀୟତା: https://jackwallner.github.io/ironman/privacy-policy.html
ବ୍ୟବହାର ସର୍ତ୍ତ: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ଏକ ସ୍ୱାଧୀନ ଆପ୍ ଏବଂ କୌଣସି ରେସ ଆୟୋଜକ କିମ୍ବା ଟାଇମିଂ କମ୍ପାନୀ ସହିତ ଜଡିତ ନୁହେଁ।""",
        "promotional_text": "ନାମ ଥରେ ଲେଖନ୍ତୁ ଏବଂ ସମସ୍ତ ପ୍ରକାଶିତ ଫଳ ଓ ସ୍ପ୍ଲିଟ୍ ଦେଖନ୍ତୁ।",
        "release_notes": "ଆପଣଙ୍କ ପ୍ରକାଶିତ ରେସ ଫଳ ଖୋଜନ୍ତୁ ଏବଂ ପ୍ରତ୍ୟେକ ସ୍ପ୍ଲିଟ୍ ଏକ ସ୍ଥାନରେ ଦେଖନ୍ତୁ।",
    },
    "pa": {
        "name": "IM Iron Splits: ਰੇਸ ਨਤੀਜੇ",
        "subtitle": "ਆਪਣੇ ਸਪਲਿਟ ਕ੍ਰਮ ਵਿੱਚ ਵੇਖੋ",
        "keywords": "ਟ੍ਰਾਇਥਲਾਨ,ਰੇਸ ਨਤੀਜੇ,ਸਪਲਿਟ,ਤੈਰਾਕੀ,ਸਾਈਕਲ,ਦੌੜ,ਬਿਬ ਨੰਬਰ,ਫਿਨਿਸ਼ ਸਮਾਂ,ਨਿੱਜੀ ਬਿਹਤਰ,ਇਤਿਹਾਸ",
        "description": """ਤੁਹਾਡੇ ਵੱਲੋਂ ਪੂਰੀ ਕੀਤੀ ਹਰ ਰੇਸ ਇੱਕ ਥਾਂ ਤੇ, ਤੁਹਾਡੇ ਪ੍ਰਦਰਸ਼ਨ ਨੂੰ ਸਮਝਣ ਲਈ ਸੁਚੱਜੇ ਢੰਗ ਨਾਲ।

ਆਪਣਾ ਨਾਮ ਇੱਕ ਵਾਰ ਲਿਖੋ। IM Iron Splits ਪ੍ਰਕਾਸ਼ਿਤ ਨਤੀਜੇ ਲੱਭ ਕੇ ਤੈਰਾਕੀ, ਟ੍ਰਾਂਜ਼ਿਸ਼ਨ, ਸਾਈਕਲ ਅਤੇ ਦੌੜ ਦੇ ਸਪਲਿਟ, ਬਿਬ ਨੰਬਰ ਅਤੇ ਰੈਂਕ ਦਿਖਾਉਂਦਾ ਹੈ।

ਨਿੱਜੀ ਬਿਹਤਰ ਸਮਾਂ ਵੇਖੋ ਅਤੇ ਇੱਕੋ ਕਿਸਮ ਦੀਆਂ ਰੇਸਾਂ ਦੀ ਤੁਲਨਾ ਕਰੋ। Race Book ਇੱਕ ਵਾਰ ਦੀ ਆਜੀਵਨ ਖਰੀਦ ਨਾਲ ਤੁਲਨਾ ਅਤੇ PDF ਜਾਂ ਤਸਵੀਰ ਐਕਸਪੋਰਟ ਖੋਲ੍ਹਦਾ ਹੈ, ਬਿਨਾਂ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਜਾਂ ਹਰ ਐਕਸਪੋਰਟ ਫੀਸ ਦੇ।

ਮੁੱਖ ਸੁਵਿਧਾਵਾਂ ਮੁਫ਼ਤ ਹਨ: ਖੋਜ, ਪੂਰਾ ਇਤਿਹਾਸ, ਸਪਲਿਟ, ਰੈਂਕ, ਨੋਟਸ ਅਤੇ Pointers ਲਾਇਬ੍ਰੇਰੀ।

ਪਰਦੇਦਾਰੀ: https://jackwallner.github.io/ironman/privacy-policy.html
ਵਰਤੋਂ ਦੀਆਂ ਸ਼ਰਤਾਂ: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ਇੱਕ ਸੁਤੰਤਰ ਐਪ ਹੈ ਅਤੇ ਕਿਸੇ ਰੇਸ ਆਯੋਜਕ ਜਾਂ ਟਾਈਮਿੰਗ ਕੰਪਨੀ ਨਾਲ ਸੰਬੰਧਿਤ ਨਹੀਂ ਹੈ।""",
        "promotional_text": "ਨਾਮ ਇੱਕ ਵਾਰ ਲਿਖੋ ਅਤੇ ਸਾਰੇ ਪ੍ਰਕਾਸ਼ਿਤ ਨਤੀਜੇ, ਸਪਲਿਟ ਅਤੇ ਰੈਂਕ ਵੇਖੋ।",
        "release_notes": "ਆਪਣੇ ਪ੍ਰਕਾਸ਼ਿਤ ਰੇਸ ਨਤੀਜੇ ਲੱਭੋ ਅਤੇ ਹਰ ਸਪਲਿਟ ਇੱਕ ਥਾਂ ਤੇ ਵੇਖੋ।",
    },
    "pl": {
        "name": "IM Iron Splits: Wyniki",
        "subtitle": "Twoje czasy, uporządkowane",
        "keywords": "triathlon,wyniki zawodów,międzyczasy,pływanie,rower,bieg,numer startowy,czas mety,rekord,historia startów",
        "description": """Każdy ukończony przez Ciebie start w jednym miejscu, uporządkowany tak, by łatwo zrozumieć wynik.

Wpisz imię i nazwisko raz. IM Iron Splits znajdzie opublikowane wyniki i pokaże czasy pływania, zmian, roweru i biegu, numer startowy oraz miejsca w kategorii i klasyfikacji generalnej.

Zobacz rekordy życiowe, porównuj podobne zawody i sprawdź, gdzie mieści się każdy czas w stawce. Race Book odblokowuje porównania i eksport do PDF lub obrazu w ramach jednorazowego zakupu na zawsze, bez subskrypcji i opłat za eksport.

Podstawowe funkcje są bezpłatne: wyszukiwanie, pełna historia, międzyczasy, rankingi, notatki i biblioteka Pointers.

Prywatność: https://jackwallner.github.io/ironman/privacy-policy.html
Warunki: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits to niezależna aplikacja, niezwiązana z organizatorami zawodów ani firmami pomiarowymi.""",
        "promotional_text": "Wpisz imię i nazwisko raz i zbierz wszystkie opublikowane czasy, wyniki oraz miejsca.",
        "release_notes": "Znajdź opublikowane wyniki i zobacz każdy międzyczas w jednym miejscu.",
    },
    "pt": {
        "name": "IM Iron Splits: Resultados",
        "subtitle": "Os teus tempos, ordenados",
        "keywords": "triatlo,resultados de provas,parciais,natação,bicicleta,corrida,dorsal,tempo final,recorde,histórico",
        "description": """Todas as provas que terminaste, num só lugar e organizadas da forma como queres compreender o teu desempenho.

Escreve o teu nome uma vez. O IM Iron Splits encontra os resultados publicados e mostra os parciais de natação, transições, bicicleta e corrida, o dorsal e as classificações.

Consulta os teus melhores tempos, compara provas do mesmo tipo e percebe a posição de cada tempo no pelotão. O Race Book desbloqueia comparações e exportação para PDF ou imagem com uma compra única vitalícia, sem subscrição nem custo por exportação.

O essencial é gratuito: pesquisa, histórico completo, parciais, classificações, notas e biblioteca Pointers.

Privacidade: https://jackwallner.github.io/ironman/privacy-policy.html
Termos: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

O IM Iron Splits é independente e não está ligado a organizadores de provas ou empresas de cronometragem.""",
        "promotional_text": "Escreve o teu nome uma vez e reúne todos os resultados, parciais e classificações publicados.",
        "release_notes": "Encontra os teus resultados publicados e consulta cada parcial num só lugar.",
    },
    "ro": {
        "name": "IM Iron Splits: Rezultate",
        "subtitle": "Timpii tăi, ordonați",
        "keywords": "triatlon,rezultate curse,splituri,înot,bicicletă,alergare,număr de concurs,timp final,record,istoric",
        "description": """Fiecare cursă terminată, într-un singur loc și ordonată pentru a-ți înțelege performanța.

Scrie-ți numele o singură dată. IM Iron Splits găsește rezultatele publicate și afișează timpii de înot, tranziții, bicicletă și alergare, numărul de concurs și clasamentele.

Vezi recordurile personale, compară curse de același tip și înțelege locul fiecărui timp în pluton. Race Book deblochează comparațiile și exportul PDF sau imagine printr-o achiziție unică pe viață, fără abonament și fără taxă pentru export.

Funcțiile de bază rămân gratuite: căutare, istoric complet, splituri, clasamente, notițe și biblioteca Pointers.

Confidențialitate: https://jackwallner.github.io/ironman/privacy-policy.html
Termeni: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits este o aplicație independentă, fără legătură cu organizatorii sau cronometrorii curselor.""",
        "promotional_text": "Scrie-ți numele o dată și adună toate rezultatele, timpii și clasamentele publicate.",
        "release_notes": "Găsește rezultatele publicate și vezi fiecare split într-un singur loc.",
    },
    "ru": {
        "name": "IM Iron Splits: Результаты",
        "subtitle": "Твои сплиты по местам",
        "keywords": "триатлон,результаты забегов,сплиты,плавание,велосипед,бег,номер,финиш,личный рекорд,история",
        "description": """Каждая завершённая гонка в одном месте, собранная так, чтобы было легко понять результат.

Введите имя один раз. IM Iron Splits найдёт опубликованные результаты и покажет сплиты плавания, транзитных зон, велосипеда и бега, номер участника и места в категории и общем зачёте.

Смотрите личные рекорды, сравнивайте гонки одного типа и понимайте место каждого времени в поле. Race Book открывает сравнения и экспорт в PDF или изображение одной пожизненной покупкой, без подписки и платы за экспорт.

Основные функции бесплатны: поиск, полная история, сплиты, рейтинги, заметки и библиотека Pointers.

Конфиденциальность: https://jackwallner.github.io/ironman/privacy-policy.html
Условия: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits независим и не связан с организаторами гонок или компаниями хронометража.""",
        "promotional_text": "Введите имя один раз и соберите все опубликованные результаты, сплиты и места.",
        "release_notes": "Найдите опубликованные результаты и смотрите каждый сплит в одном месте.",
    },
    "sk": {
        "name": "IM Iron Splits: Výsledky",
        "subtitle": "Vaše časy zoradené",
        "keywords": "triatlon,výsledky pretekov,medzičasy,plávanie,bicykel,beh,štartové číslo,čas,rekord,história",
        "description": """Každé preteky, ktoré ste dokončili, na jednom mieste a usporiadané tak, aby ste im rozumeli.

Zadajte meno raz. IM Iron Splits nájde zverejnené výsledky a zobrazí časy plávania, depa, bicykla a behu, štartové číslo a umiestnenia.

Pozrite si osobné rekordy, porovnajte preteky rovnakého typu a zistite miesto každého času v poli. Race Book odomkne porovnania a export do PDF alebo obrázka jednorazovým doživotným nákupom, bez predplatného a bez poplatku za export.

Základ ostáva bezplatný: vyhľadávanie, celá história, medzičasy, poradia, poznámky a knižnica Pointers.

Súkromie: https://jackwallner.github.io/ironman/privacy-policy.html
Podmienky: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits je nezávislá aplikácia bez väzby na organizátorov pretekov alebo časomerné firmy.""",
        "promotional_text": "Zadajte meno raz a majte všetky zverejnené výsledky a medzičasy na jednom mieste.",
        "release_notes": "Nájdite zverejnené výsledky a pozrite si každý medzičas na jednom mieste.",
    },
    "sl": {
        "name": "IM Iron Splits: Rezultati",
        "subtitle": "Tvoji časi, razvrščeni",
        "keywords": "triatlon,rezultati tekem,delni časi,plavanje,kolo,tek,štartna številka,končni čas,osebni rekord,zgodovina",
        "description": """Vsaka tekma, ki si jo končal, na enem mestu in urejena tako, da razumeš svoj nastop.

Vnesi ime enkrat. IM Iron Splits poišče objavljene rezultate in prikaže čase plavanja, menjav, kolesa in teka, štartno številko ter uvrstitve.

Oglej si osebne rekorde, primerjaj tekme iste vrste in razumi mesto vsakega časa v skupini. Race Book odklene primerjave ter izvoz v PDF ali sliko z enkratnim doživljenjskim nakupom, brez naročnine in brez plačila za izvoz.

Osnova ostane brezplačna: iskanje, celotna zgodovina, delni časi, uvrstitve, opombe in knjižnica Pointers.

Zasebnost: https://jackwallner.github.io/ironman/privacy-policy.html
Pogoji: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits je neodvisna aplikacija brez povezave z organizatorji tekem ali merilci časa.""",
        "promotional_text": "Vnesi ime enkrat in zberi vse objavljene rezultate, čase in uvrstitve.",
        "release_notes": "Poišči objavljene rezultate in si oglej vsak delni čas na enem mestu.",
    },
    "sv": {
        "name": "IM Iron Splits: Resultat",
        "subtitle": "Dina lopp, sorterade tider",
        "keywords": "triathlon,loppresultat,mellantider,simning,c ykling,löpning,nummer,sluttid,personligt rekord,löphistorik".replace("c ykling", "cykling"),
        "description": """Alla lopp du har genomfört, på ett ställe och sorterade så att du kan förstå prestationen.

Skriv ditt namn en gång. IM Iron Splits hittar publicerade resultat och visar tider för simning, växlingar, cykling och löpning, nummer och placeringar.

Se personliga rekord, jämför lopp av samma typ och förstå var varje tid hamnar i fältet. Race Book låser upp jämförelser och export till PDF eller bild med ett engångsköp för livet, utan abonnemang eller avgift per export.

Kärnan är gratis: sökning, full historik, mellantider, placeringar, anteckningar och Pointers-biblioteket.

Integritet: https://jackwallner.github.io/ironman/privacy-policy.html
Villkor: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits är oberoende och inte kopplad till tävlingsarrangörer eller tidtagningsföretag.""",
        "promotional_text": "Skriv ditt namn en gång och samla alla publicerade resultat, tider och placeringar.",
        "release_notes": "Hitta publicerade resultat och se varje mellantid på ett ställe.",
    },
    "ta": {
        "name": "IM Iron Splits: ரேஸ் முடிவுகள்",
        "subtitle": "ஸ்ப்ளிட்கள் வரிசையில்",
        "keywords": "டிரையத்லான்,ரேஸ் முடிவுகள்,ஸ்ப்ளிட்,நீச்சல்,சைக்கிள்,ஓட்டம்,பிப் எண்,முடிவு நேரம்,சிறந்த நேரம்,வரலாறு",
        "description": """நீங்கள் முடித்த ஒவ்வொரு ரேஸும் ஒரே இடத்தில், உங்கள் செயல்திறனைப் புரிந்துகொள்ள எளிதாக.

உங்கள் பெயரை ஒருமுறை உள்ளிடுங்கள். IM Iron Splits வெளியிடப்பட்ட முடிவுகளைத் தேடி நீச்சல், டிரான்சிஷன், சைக்கிள் மற்றும் ஓட்ட ஸ்ப்ளிட்கள், பிப் எண் மற்றும் தரவரிசைகளை காட்டுகிறது.

தனிப்பட்ட சிறந்த நேரங்களைப் பார்த்து, ஒரே வகை ரேஸ்களை ஒப்பிடுங்கள். Race Book ஒருமுறை வாங்கும் வாழ்நாள் அணுகலுடன் ஒப்பீடு மற்றும் PDF அல்லது பட ஏற்றுமதியைத் திறக்கிறது, சந்தா அல்லது ஒவ்வொரு ஏற்றுமதிக்கும் கட்டணம் இல்லை.

முக்கிய அம்சங்கள் இலவசம்: தேடல், முழு வரலாறு, ஸ்ப்ளிட்கள், தரவரிசைகள், குறிப்புகள் மற்றும் Pointers நூலகம்.

தனியுரிமை: https://jackwallner.github.io/ironman/privacy-policy.html
பயன்பாட்டு விதிமுறைகள்: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ஒரு சுயாதீன செயலி; எந்த ரேஸ் அமைப்பாளர் அல்லது நேரக் கணிப்பு நிறுவனத்துடனும் இணைக்கப்படவில்லை.""",
        "promotional_text": "பெயரை ஒருமுறை உள்ளிட்டு வெளியிடப்பட்ட அனைத்து முடிவுகளையும் ஸ்ப்ளிட்களையும் காணுங்கள்.",
        "release_notes": "வெளியிடப்பட்ட ரேஸ் முடிவுகளைக் கண்டுபிடித்து ஒவ்வொரு ஸ்ப்ளிட்டையும் ஒரே இடத்தில் பாருங்கள்.",
    },
    "te": {
        "name": "IM Iron Splits: రేస్ ఫలితాలు",
        "subtitle": "మీ స్ప్లిట్‌లను క్రమంలో చూడండి",
        "keywords": "ట్రయాథ్లాన్,రేస్ ఫలితాలు,స్ప్లిట్,ఈత,బైక్,పరుగు,బిబ్ నంబర్,ఫినిష్ సమయం,వ్యక్తిగత రికార్డు,చరిత్ర",
        "description": """మీరు పూర్తి చేసిన ప్రతి రేస్ ఒకే చోట, మీ ప్రదర్శనను అర్థం చేసుకోవడానికి సులభంగా.

మీ పేరును ఒక్కసారి నమోదు చేయండి. IM Iron Splits ప్రచురించిన ఫలితాలను కనుగొని ఈత, ట్రాన్సిషన్, బైక్ మరియు పరుగు స్ప్లిట్‌లు, బిబ్ నంబర్, ర్యాంక్‌లను చూపిస్తుంది.

వ్యక్తిగత అత్యుత్తమాలను చూడండి, ఒకే రకమైన రేస్‌లను పోల్చండి. Race Book ఒక్కసారి జీవితకాల కొనుగోలుతో పోలిక మరియు PDF లేదా చిత్రం ఎగుమతిని తెరుస్తుంది, సబ్‌స్క్రిప్షన్ లేదా ప్రతి ఎగుమతికి రుసుము లేదు.

ప్రధాన సౌకర్యాలు ఉచితం: శోధన, పూర్తి చరిత్ర, స్ప్లిట్‌లు, ర్యాంక్‌లు, నోట్లు మరియు Pointers లైబ్రరీ.

గోప్యత: https://jackwallner.github.io/ironman/privacy-policy.html
వినియోగ నిబంధనలు: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits స్వతంత్ర యాప్, రేస్ నిర్వాహకులు లేదా టైమింగ్ కంపెనీలతో అనుబంధం లేదు.""",
        "promotional_text": "పేరు ఒక్కసారి నమోదు చేసి ప్రచురించిన అన్ని ఫలితాలు మరియు స్ప్లిట్‌లను చూడండి.",
        "release_notes": "మీ ప్రచురించిన రేస్ ఫలితాలను కనుగొని ప్రతి స్ప్లిట్‌ను ఒకే చోట చూడండి.",
    },
    "th": {
        "name": "IM Iron Splits: ผลการแข่งขัน",
        "subtitle": "เรียงเวลาของคุณตามประเภท",
        "keywords": "ไตรกีฬา,ผลการแข่งขัน,สปลิต,ว่ายน้ำ,จักรยาน,วิ่ง,หมายเลข,เวลาจบ,สถิติส่วนตัว,ประวัติ",
        "description": """ทุกการแข่งขันที่คุณจบ รวมไว้ในที่เดียวและจัดเรียงเพื่อให้เข้าใจผลงานได้ง่าย

กรอกชื่อครั้งเดียว IM Iron Splits ค้นหาผลการแข่งขันที่เผยแพร่แล้ว และแสดงเวลาว่ายน้ำ ทรานซิชัน จักรยาน และวิ่ง รวมถึงหมายเลขและอันดับ

ดูสถิติส่วนตัว เปรียบเทียบการแข่งขันประเภทเดียวกัน และดูตำแหน่งของแต่ละเวลาในกลุ่มผู้แข่งขัน Race Book ปลดล็อกการเปรียบเทียบและการส่งออกเป็น PDF หรือรูปภาพด้วยการซื้อครั้งเดียวตลอดชีพ ไม่มีสมาชิกและไม่มีค่าธรรมเนียมต่อการส่งออก

ฟีเจอร์หลักยังใช้ฟรี: ค้นหา ประวัติทั้งหมด สปลิต อันดับ โน้ต และคลัง Pointers

ความเป็นส่วนตัว: https://jackwallner.github.io/ironman/privacy-policy.html
ข้อกำหนด: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits เป็นแอปอิสระ ไม่ได้เกี่ยวข้องกับผู้จัดการแข่งขันหรือบริษัทจับเวลาใด ๆ""",
        "promotional_text": "กรอกชื่อครั้งเดียว แล้วดูผลการแข่งขัน สปลิต และอันดับที่เผยแพร่ทั้งหมด",
        "release_notes": "ค้นหาผลการแข่งขันที่เผยแพร่แล้ว และดูทุกสปลิตในที่เดียว",
    },
    "tr": {
        "name": "IM Iron Splits: Yarışlar",
        "subtitle": "Yarış sürelerin sıralı",
        "keywords": "triatlon,yarış sonuçları,ara zamanlar,yüzme,bisiklet,koşu,göğüs numarası,bitiş süresi,kişisel rekor,geçmiş",
        "description": """Tamamladığın her yarış tek yerde ve performansını anlamanı kolaylaştıracak şekilde sıralanır.

Adını bir kez yaz. IM Iron Splits yayımlanmış sonuçlarını bulur; yüzme, geçiş, bisiklet ve koşu sürelerini, göğüs numaranı ve derecelerini gösterir.

Kişisel en iyilerini gör, aynı tür yarışları karşılaştır ve her sürenin yarış alanındaki yerini anla. Race Book, tek seferlik ömür boyu satın alımla karşılaştırma ve PDF veya görsel dışa aktarmayı açar; abonelik ya da dışa aktarma başına ücret yoktur.

Temel özellikler ücretsizdir: arama, tam geçmiş, ara zamanlar, sıralamalar, notlar ve Pointers kitaplığı.

Gizlilik: https://jackwallner.github.io/ironman/privacy-policy.html
Koşullar: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits bağımsızdır, yarış organizatörleri veya zamanlama şirketleriyle bağlantılı değildir.""",
        "promotional_text": "Adını bir kez yaz ve yayımlanmış tüm sonuçlarını, sürelerini ve derecelerini topla.",
        "release_notes": "Yayımlanmış sonuçlarını bul ve her ara zamanı tek yerde gör.",
    },
    "uk": {
        "name": "IM Iron Splits: Результати",
        "subtitle": "Твої спліти за місцями",
        "keywords": "тріатлон,результати забігів,спліти,плавання,велосипед,біг,номер,фініш,особистий рекорд,історія",
        "description": """Кожна завершена гонка в одному місці, зібрана так, щоб легко зрозуміти результат.

Введи ім’я один раз. IM Iron Splits знайде опубліковані результати й покаже спліти плавання, транзитних зон, велосипеда та бігу, номер учасника й місця в категорії та загальному заліку.

Переглядай особисті рекорди, порівнюй гонки одного типу та розумій місце кожного часу в полі. Race Book відкриває порівняння й експорт у PDF або зображення однією довічною покупкою, без підписки та плати за експорт.

Основні функції безкоштовні: пошук, повна історія, спліти, рейтинги, нотатки та бібліотека Pointers.

Конфіденційність: https://jackwallner.github.io/ironman/privacy-policy.html
Умови: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits незалежний і не пов’язаний з організаторами перегонів чи компаніями хронометражу.""",
        "promotional_text": "Введи ім’я один раз і зберігай усі опубліковані результати, спліти та місця.",
        "release_notes": "Знайди опубліковані результати й переглядай кожен спліт в одному місці.",
    },
    "ur": {
        "name": "IM Iron Splits: ریس نتائج",
        "subtitle": "اپنے اسپلٹس ترتیب سے دیکھیں",
        "keywords": "ٹرائیتھلون,ریس نتائج,اسپلٹس,تیراکی,سائیکل,دوڑ,بب نمبر,اختتامی وقت,ذاتی بہترین,ریس تاریخ",
        "description": """آپ نے جو ہر ریس مکمل کی ہے، وہ ایک جگہ پر اور کارکردگی سمجھنے کے لیے آسان انداز میں۔

اپنا نام ایک بار درج کریں۔ IM Iron Splits شائع شدہ نتائج تلاش کر کے تیراکی، ٹرانزیشن، سائیکل اور دوڑ کے اسپلٹس، بب نمبر اور رینک دکھاتا ہے۔

ذاتی بہترین وقت دیکھیں اور ایک ہی قسم کی ریس کا موازنہ کریں۔ Race Book ایک بار کی تاحیات خریداری سے موازنہ اور PDF یا تصویر ایکسپورٹ کھولتا ہے، بغیر سبسکرپشن یا فی ایکسپورٹ فیس کے۔

بنیادی سہولیات مفت ہیں: تلاش، مکمل تاریخ، اسپلٹس، رینک، نوٹس اور Pointers لائبریری۔

رازداری: https://jackwallner.github.io/ironman/privacy-policy.html
استعمال کی شرائط: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits ایک آزاد ایپ ہے اور کسی ریس منتظم یا ٹائمنگ کمپنی سے وابستہ نہیں۔""",
        "promotional_text": "نام ایک بار درج کریں اور تمام شائع شدہ نتائج، اسپلٹس اور رینک دیکھیں۔",
        "release_notes": "اپنے شائع شدہ ریس نتائج تلاش کریں اور ہر اسپلٹ ایک جگہ دیکھیں۔",
    },
    "vi": {
        "name": "IM Iron Splits: Kết quả",
        "subtitle": "Xếp hạng các chặng đua",
        "keywords": "ba môn phối hợp,kết quả cuộc đua,split,bơi,đạp xe,chạy,số báo danh,thời gian về đích,kỷ lục,lịch sử",
        "description": """Mọi cuộc đua bạn đã hoàn thành, ở một nơi và được sắp xếp để bạn hiểu thành tích của mình.

Nhập tên một lần. IM Iron Splits tìm kết quả đã công bố và hiển thị thời gian bơi, chuyển tiếp, đạp xe và chạy, số báo danh cùng thứ hạng.

Xem thành tích tốt nhất, so sánh các cuộc đua cùng loại và hiểu vị trí của từng thời gian trong nhóm. Race Book mở khóa so sánh và xuất PDF hoặc hình ảnh bằng một lần mua trọn đời, không đăng ký và không tính phí mỗi lần xuất.

Các tính năng cốt lõi vẫn miễn phí: tìm kiếm, lịch sử đầy đủ, split, thứ hạng, ghi chú và thư viện Pointers.

Quyền riêng tư: https://jackwallner.github.io/ironman/privacy-policy.html
Điều khoản: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits là ứng dụng độc lập, không liên kết với ban tổ chức hay công ty tính giờ cuộc đua.""",
        "promotional_text": "Nhập tên một lần để gom mọi kết quả, split và thứ hạng đã được công bố.",
        "release_notes": "Tìm kết quả cuộc đua đã công bố và xem mọi split ở một nơi.",
    },
    "zh-Hans": {
        "name": "IM Iron Splits: 比赛成绩",
        "subtitle": "按排名查看你的分段",
        "keywords": "铁人三项,比赛成绩,分段,游泳,自行车,跑步,号码布,完赛时间,个人最佳,比赛记录",
        "description": """把你完成过的每场比赛集中在一个地方，并按你真正关心的方式整理。

只需输入一次姓名。IM Iron Splits 会查找已发布的成绩，显示游泳、换项、自行车和跑步分段、号码布以及组别和总排名。

查看个人最佳，比较同类型比赛，了解每个用时在参赛者中的位置。Race Book 通过一次性终身购买解锁比较，以及 PDF 或图片导出。没有订阅，也不会按导出次数收费。

核心功能免费提供：搜索、完整历史、分段、排名、笔记和 Pointers 内容库。

隐私政策: https://jackwallner.github.io/ironman/privacy-policy.html
使用条款: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits 是独立应用，与任何比赛主办方或计时公司没有关联。""",
        "promotional_text": "输入一次姓名，集中查看所有已发布的成绩、分段和排名。",
        "release_notes": "查找已发布的比赛成绩，在一个地方查看所有分段。",
    },
    "zh-Hant": {
        "name": "IM Iron Splits: 比賽成績",
        "subtitle": "依排名查看你的分段",
        "keywords": "鐵人三項,比賽成績,分段,游泳,自行車,跑步,號碼布,完賽時間,個人最佳,比賽紀錄",
        "description": """把你完成過的每場比賽集中在一個地方，並依照你真正關心的方式整理。

只要輸入一次姓名。IM Iron Splits 會尋找已發佈的成績，顯示游泳、轉換、自行車和跑步分段、號碼布，以及組別和總排名。

查看個人最佳，比較同類型比賽，了解每個時間在參賽者中的位置。Race Book 透過一次性終身購買解鎖比較，以及 PDF 或圖片匯出。沒有訂閱，也不會按匯出次數收費。

核心功能免費提供：搜尋、完整歷史、分段、排名、筆記和 Pointers 內容庫。

隱私權政策: https://jackwallner.github.io/ironman/privacy-policy.html
使用條款: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

IM Iron Splits 是獨立應用程式，與任何比賽主辦方或計時公司沒有關聯。""",
        "promotional_text": "輸入一次姓名，集中查看所有已發佈的成績、分段和排名。",
        "release_notes": "尋找已發佈的比賽成績，在一個地方查看所有分段。",
    },
}


LOCALE_TO_LANGUAGE = {
    "ar-SA": "ar", "bn-BD": "bn", "ca": "ca", "cs": "cs", "da": "da",
    "de-DE": "de", "el": "el", "en-AU": "en", "en-CA": "en", "en-GB": "en",
    "en-US": "en", "es-ES": "es", "es-MX": "es", "fi": "fi", "fr-CA": "fr",
    "fr-FR": "fr", "gu-IN": "gu", "he": "he", "hi": "hi", "hr": "hr",
    "hu": "hu", "id": "id", "it": "it", "ja": "ja", "kn-IN": "kn", "ko": "ko",
    "ml-IN": "ml", "mr-IN": "mr", "ms": "ms", "nl-NL": "nl", "no": "no",
    "or-IN": "or", "pa-IN": "pa", "pl": "pl", "pt-BR": "pt", "pt-PT": "pt",
    "ro": "ro", "ru": "ru", "sk": "sk", "sl-SI": "sl", "sv": "sv", "ta-IN": "ta",
    "te-IN": "te", "th": "th", "tr": "tr", "uk": "uk", "ur-PK": "ur", "vi": "vi",
    "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant",
}


def write_metadata(locale: str, values: dict[str, str]) -> None:
    directory = METADATA / locale
    directory.mkdir(parents=True, exist_ok=True)
    merged = {**values, **URLS}
    for key, value in merged.items():
        if key == "keywords":
            words: list[str] = []
            length = 0
            for word in value.split(","):
                candidate = word if not words else f",{word}"
                if length + len(candidate) > 100:
                    break
                words.append(word)
                length += len(candidate)
            value = ",".join(words)
        (directory / f"{key}.txt").write_text(value.strip() + "\n", encoding="utf-8")


def main() -> None:
    for locale in LOCALES:
        language = LOCALE_TO_LANGUAGE[locale]
        values = ENGLISH if language == "en" else COPY[language]
        write_metadata(locale, values)
    print(f"generated {len(LOCALES)} locale metadata directories")


if __name__ == "__main__":
    main()
