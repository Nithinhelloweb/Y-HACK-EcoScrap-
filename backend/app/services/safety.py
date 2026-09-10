from typing import Dict, Any, List

SAFETY_PROTOCOLS = {
    "SWOLLEN_LITHIUM_BATTERY": {
        "hazard_level": "CRITICAL",
        "title": "Swollen Lithium-Ion / Polymer Battery",
        "title_ta": "வீங்கிய லித்தியம் பேட்டரி",
        "title_hi": "फूली हुई लिथियम बैटरी",
        "risks": [
            "Thermal runaway and uncontrollable fire (up to 600°C)",
            "Toxic hydrogen fluoride gas emissions",
            "Explosion if punctured or compressed"
        ],
        "mandatory_ppe": ["Heat-resistant gloves", "Safety goggles", "Fire-retardant apron"],
        "handling_sop": [
            "NEVER attempt to puncture, press, or pierce the battery pack.",
            "Do not charge or expose to heat, sunlight, or metal tools.",
            "Cover terminal contacts immediately with electrical PVC insulating tape.",
            "Store individually submerged in dry sand or vermiculite fire bucket.",
            "Do NOT store in airtight containers (allow venting)."
        ],
        "handling_sop_ta": [
            "பேட்டரியை எக்காரணம் கொண்டும் குத்தவோ, அழுத்தவோ கூடாது.",
            "வெயில், வெப்பம் அல்லது உலோகப் பொருட்களின் அருகே வைக்காதீர்கள்.",
            "முனைகளை இன்சுலேஷன் டேப் போட்டு உடனடியாக மூடுங்கள்.",
            "உலர்ந்த மணல் வாளியில் தனியாகப் பாதுகாப்பாக வையுங்கள்."
        ],
        "handling_sop_hi": [
            "बैटरी को किसी भी स्थिति में छेदें या दबाएं नहीं।",
            "धूप, गर्मी या धातु के औजारों के पास न रखें।",
            "टर्मिनल सिरों को तुरंत इन्सुलेशन टेप से ढक दें।",
            "सूखी रेत की बाल्टी में अलग सुरक्षित रखें।"
        ]
    },
    "CRT_MONITOR_LEAD_GLASS": {
        "hazard_level": "HIGH",
        "title": "Cathode Ray Tube (CRT) / Heavy Glass Monitor",
        "title_ta": "CRT மானிட்டர் மற்றும் ஈய கண்ணாடி",
        "title_hi": "सीआरटी मॉनिटर और लेड ग्लास",
        "risks": [
            "Vacuum implosion with flying heavy glass shards",
            "High lead oxide toxicity (up to 2.5 kg lead per tube)",
            "Phosphor powder inhalation risk"
        ],
        "mandatory_ppe": ["Heavy puncture gloves", "Full face shield", "N95/FFP2 dust mask"],
        "handling_sop": [
            "Do NOT smash the neck or face of the CRT tube.",
            "Vent the vacuum safely at the tip under local exhaust or controlled environment.",
            "Transport face-down on padded blankets to prevent neck fracture.",
            "Never mix leaded funnel glass with common scrap glass."
        ],
        "handling_sop_ta": [
            "CRT கண்ணாடியை அடித்து உடைக்கக் கூடாது.",
            "கண்ணாடியை முகம் கீழ்நோக்கி இருக்கும்படி பாதுகாப்பாக எடுத்துச் செல்லுங்கள்.",
            "கண்ணாடித் துகள்களை சுவாசிப்பதைத் தவிர்க்க முகக்கவசம் அணியுங்கள்."
        ],
        "handling_sop_hi": [
            "सीआरटी ट्यूब को हथौड़े या डंडे से न तोड़ें।",
            "सुरक्षित रूप से फेस-डाउन स्थिति में ले जाएं।",
            "धूल और शीशे के कणों से बचने के लिए मास्क पहनें।"
        ]
    },
    "LEAD_ACID_INVERTER": {
        "hazard_level": "CRITICAL",
        "title": "Lead-Acid Inverter / UPS Battery",
        "title_ta": "லெட்-ஆசிட் இன்வெர்ட்டர் பேட்டரி",
        "title_hi": "लेड-एसिड इन्वर्टर बैटरी",
        "risks": [
            "Severe chemical burns from 30-40% concentrated sulfuric acid",
            "Chronic lead poisoning affecting nervous system and kidneys",
            "Hydrogen gas explosion risk near sparks"
        ],
        "mandatory_ppe": ["Acid-resistant nitrile/butyl gloves", "Splash goggles", "Rubber boots"],
        "handling_sop": [
            "Keep upright at all times; never tip or lay flat.",
            "If leaking acid, neutralize immediately with baking soda (sodium bicarbonate) slurry.",
            "Never pour spent battery acid down municipal drains or into soil.",
            "Route only to authorized formal secondary lead smelters."
        ],
        "handling_sop_ta": [
            "எப்போதும் பேட்டரியை நேராக மட்டுமே வைக்க வேண்டும்; சாய்க்கக் கூடாது.",
            "அமிலம் கசிந்தால் பேக்கிங் சோடா தெளித்து நடுநிலையாக்கவும்.",
            "கழிவு அமிலத்தை வடிகால் அல்லது மண்ணில் ஊற்றக் கூடாது."
        ],
        "handling_sop_hi": [
            "बैटरी को हमेशा सीधा रखें, कभी भी झुकाएं नहीं।",
            "यदि एसिड रिस रहा हो, तो बेकिंग सोडा डालकर निष्प्रभावी करें।",
            "एसिड को नाली या मिट्टी में कभी न बहाएं।"
        ]
    },
    "CABLE_OPEN_BURNING": {
        "hazard_level": "HIGH",
        "title": "Prohibited Cable Burning Warning",
        "title_ta": "கம்பிகளை எரிப்பது தடைசெய்யப்பட்டுள்ளது",
        "title_hi": "तार जलाना सख्त मना है",
        "risks": [
            "Release of highly toxic chlorinated dioxins and furans",
            "Severe lung damage, respiratory failure, and cancer risk",
            "Legal penalty and seizure under E-Waste Management Rules 2022"
        ],
        "mandatory_ppe": ["Cut-resistant leather gloves"],
        "handling_sop": [
            "NEVER burn PVC coated cables to extract copper.",
            "Use manual wire stripping tools or rotary mechanical strippers.",
            "Formal recyclers offer higher prices for unburned bright copper wire."
        ],
        "handling_sop_ta": [
            "செம்பு எடுக்க கம்பிகளை எரிக்கக் கூடாது; இது புற்றுநோய் நச்சுப் புகையை வெளியிடும்.",
            "கம்பி உரிக்க கத்தி அல்லது ஸ்ட்ரிப்பர் கருவியைப் பயன்படுத்துங்கள்.",
            "எரிக்கப்படாத செம்புக்கு மண்டியிலும் ரீசைக்கிளர்களிடமும் அதிக விலை கிடைக்கும்."
        ],
        "handling_sop_hi": [
            "तांबा निकालने के लिए तारों को कभी न जलाएं; इससे विषैली गैसें निकलती हैं।",
            "तार छीलने वाले औजारों का उपयोग करें।",
            "बिना जले साफ तांबे के लिए अधिक मूल्य प्राप्त करें।"
        ]
    }
}

def assess_safety_risk(category: str, subcategory: str, condition: str = "normal") -> Dict[str, Any]:
    """
    Evaluates context-aware hazard profile for a collection lot.
    """
    cat_upper = category.upper()
    sub_upper = subcategory.upper()
    cond_lower = condition.lower()

    if "BATTERY" in cat_upper:
        if "LEAD" in sub_upper or "UPS" in sub_upper:
            protocol = SAFETY_PROTOCOLS["LEAD_ACID_INVERTER"]
            return {
                "hazard_level": protocol["hazard_level"],
                "hazard_type": "CORROSIVE_ACID_LEAD",
                "title": protocol["title"],
                "title_ta": protocol["title_ta"],
                "title_hi": protocol["title_hi"],
                "mandatory_ppe": protocol["mandatory_ppe"],
                "risks": protocol["risks"],
                "handling_sop": protocol["handling_sop"],
                "handling_sop_ta": protocol["handling_sop_ta"],
                "handling_sop_hi": protocol["handling_sop_hi"],
                "cpcb_compliant": True,
                "urgency": "IMMEDIATE_UPRIGHT_ISOLATION"
            }
        else: # Lithium-Ion
            protocol = SAFETY_PROTOCOLS["SWOLLEN_LITHIUM_BATTERY"]
            is_critical = any(c in cond_lower for c in ["swollen", "bulging", "damaged", "வீங்கிய", "फुला"])
            level = "CRITICAL" if is_critical else "MEDIUM"
            return {
                "hazard_level": level,
                "hazard_type": "THERMAL_RUNAWAY_PUNCTURE",
                "title": protocol["title"],
                "title_ta": protocol["title_ta"],
                "title_hi": protocol["title_hi"],
                "mandatory_ppe": protocol["mandatory_ppe"],
                "risks": protocol["risks"],
                "handling_sop": protocol["handling_sop"],
                "handling_sop_ta": protocol["handling_sop_ta"],
                "handling_sop_hi": protocol["handling_sop_hi"],
                "cpcb_compliant": True,
                "urgency": "SAND_BUCKET_CONTAINMENT" if is_critical else "STANDARD_ISOLATION"
            }

    elif "CABLE" in cat_upper:
        protocol = SAFETY_PROTOCOLS["CABLE_OPEN_BURNING"]
        return {
            "hazard_level": "LOW",
            "hazard_type": "NO_OPEN_BURNING",
            "title": protocol["title"],
            "title_ta": protocol["title_ta"],
            "title_hi": protocol["title_hi"],
            "mandatory_ppe": protocol["mandatory_ppe"],
            "risks": protocol["risks"],
            "handling_sop": protocol["handling_sop"],
            "handling_sop_ta": protocol["handling_sop_ta"],
            "handling_sop_hi": protocol["handling_sop_hi"],
            "cpcb_compliant": True,
            "urgency": "MECHANICAL_STRIP_ONLY"
        }

    else:
        # Standard electronic scrap
        return {
            "hazard_level": "LOW",
            "hazard_type": "STANDARD_EWASTE",
            "title": "General Electronic Scrap Handling",
            "title_ta": "பொது மின்னணு கழிவு கையாளுதல்",
            "title_hi": "सामान्य इलेक्ट्रॉनिक कचरा प्रबंधन",
            "mandatory_ppe": ["Work gloves", "Safety shoes"],
            "risks": ["Sharp board edges", "Minor capacitor discharge"],
            "handling_sop": [
                "Handle boards by the perimeter edges.",
                "Store in covered, dry containers off damp ground.",
                "Do not practice informal cyanide or acid leaching."
            ],
            "handling_sop_ta": [
                "பலகைகளின் விளிம்புகளைப் பிடித்து கையாளவும்.",
                "ஈரப்பதம் இல்லாத உலர்ந்த இடத்தில் சேமிக்கவும்.",
                "முறைசாரா ரசாயன அல்லது அமில சிகிச்சையைத் தவிர்க்கவும்."
            ],
            "handling_sop_hi": [
                "सर्किट बोर्डों को किनारों से पकड़कर संभालें।",
                "सूखी और सुरक्षित जगह पर रखें।",
                "अवैध तेजाब या रासायनिक धुलाई न करें।"
            ],
            "cpcb_compliant": True,
            "urgency": "ROUTINE_STORAGE"
        }
