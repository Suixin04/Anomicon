export interface PreviewPoint {
  x: number;
  y: number;
}

export interface PreviewTransform extends PreviewPoint {
  scale: number;
}

/** Positions are in vp relative to the fixed viewport. Translation is measured from its center. */
export class ImagePreviewGeometry {
  width: number = 0;
  height: number = 0;
  imageRatio: number = 1;

  pan(scale: number, x: number, y: number): PreviewTransform {
    const fittedWidth = Math.min(this.width, this.height * this.imageRatio);
    const fittedHeight = Math.min(this.height, this.width / this.imageRatio);
    const limitX = Math.max(0, (fittedWidth * scale - this.width) / 2);
    const limitY = Math.max(0, (fittedHeight * scale - this.height) / 2);
    return {
      scale: scale,
      x: Math.max(-limitX, Math.min(limitX, x)),
      y: Math.max(-limitY, Math.min(limitY, y))
    };
  }

  zoom(start: PreviewTransform, requestedScale: number, from: PreviewPoint, to: PreviewPoint): PreviewTransform {
    const scale = Math.max(1, Math.min(4, requestedScale));
    const ratio = scale / start.scale;
    const centerX = this.width / 2;
    const centerY = this.height / 2;
    // Keep the same point of the image under the fingers as their distance or midpoint changes.
    return this.pan(scale,
      to.x - centerX - (from.x - centerX - start.x) * ratio,
      to.y - centerY - (from.y - centerY - start.y) * ratio);
  }
}
