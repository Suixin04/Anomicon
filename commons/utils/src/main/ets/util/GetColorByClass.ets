import { scpClassColor } from '../model/SCPClassColor';

/**
 * 根据SCP威胁等级获取对应的颜色资源
 * @param objectClass SCP威胁等级
 * @returns 包含文字颜色、背景颜色和边框颜色的对象
 */
export function getColorsByClass(objectClass: string): scpClassColor {
  const normalizedClass = objectClass.toLowerCase();

  if (normalizedClass === 'safe') {
    return {
      textColor: $r('app.color.scp_safe_text'),
      backgroundColor: $r('app.color.scp_safe_bg'),
      borderColor: $r('app.color.scp_safe_border')
    };
  } else if (normalizedClass === 'euclid') {
    return {
      textColor: $r('app.color.scp_euclid_text'),
      backgroundColor: $r('app.color.scp_euclid_bg'),
      borderColor: $r('app.color.scp_euclid_border')
    };
  } else if (normalizedClass === 'keter') {
    return {
      textColor: $r('app.color.scp_keter_text'),
      backgroundColor: $r('app.color.scp_keter_bg'),
      borderColor: $r('app.color.scp_keter_border')
    };
  } else if (normalizedClass === 'thaumiel') {
    return {
      textColor: $r('app.color.scp_thaumiel_text'),
      backgroundColor: $r('app.color.scp_thaumiel_bg'),
      borderColor: $r('app.color.scp_thaumiel_border')
    };
  } else if (normalizedClass === 'apollyon') {
    return {
      textColor: $r('app.color.scp_apollyon_text'),
      backgroundColor: $r('app.color.scp_apollyon_bg'),
      borderColor: $r('app.color.scp_apollyon_border')
    };
  } else if (normalizedClass === 'explained') {
    return {
      textColor: $r('app.color.scp_explained_text'),
      backgroundColor: $r('app.color.scp_explained_bg'),
      borderColor: $r('app.color.scp_explained_border')
    };
  } else {
    return {
      textColor: $r('app.color.scp_default_text'),
      backgroundColor: $r('app.color.scp_default_bg'),
      borderColor: $r('app.color.scp_default_border')
    };
  }
}