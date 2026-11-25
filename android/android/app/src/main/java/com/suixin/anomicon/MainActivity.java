package com.suixin.anomicon;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

public final class MainActivity extends FlutterActivity {
    private static final int PICK_ATTACHMENT = 4726;
    private static final int MAX_ATTACHMENT_BYTES = 2 * 1024 * 1024;

    private MethodChannel.Result pendingAttachment;

    @Override
    public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "anomicon/app_info")
                .setMethodCallHandler((call, result) -> {
                    if (!call.method.equals("getVersion")) {
                        result.notImplemented();
                        return;
                    }
                    try {
                        result.success(getPackageManager().getPackageInfo(getPackageName(), 0).versionName);
                    } catch (PackageManager.NameNotFoundException e) {
                        result.error("version_unavailable", "Could not read the installed app version.", null);
                    }
                });
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "anomicon/raisa_attachments")
                .setMethodCallHandler((call, result) -> {
                    if (!call.method.equals("pick")) {
                        result.notImplemented();
                        return;
                    }
                    Object imagesOnly = call.argument("imagesOnly");
                    if (!(imagesOnly instanceof Boolean)) {
                        result.error("invalid_arguments", "imagesOnly must be a boolean.", null);
                        return;
                    }
                    pickAttachment((Boolean) imagesOnly, result);
                });
    }

    private void pickAttachment(boolean imagesOnly, MethodChannel.Result result) {
        if (pendingAttachment != null) {
            result.error("busy", "An attachment selection is already in progress.", null);
            return;
        }
        Intent picker = new Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType(imagesOnly ? "image/*" : "*/*");
        try {
            pendingAttachment = result;
            startActivityForResult(picker, PICK_ATTACHMENT);
        } catch (ActivityNotFoundException e) {
            pendingAttachment = null;
            result.error("unavailable", "The Android file picker is unavailable.", null);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != PICK_ATTACHMENT || pendingAttachment == null) {
            return;
        }
        MethodChannel.Result result = pendingAttachment;
        if (resultCode != Activity.RESULT_OK) {
            pendingAttachment = null;
            result.success(null);
            return;
        }
        Uri uri = data == null ? null : data.getData();
        if (uri == null || !ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())) {
            pendingAttachment = null;
            result.error("read_failed", "Android did not return a readable document.", null);
            return;
        }
        CompletableFuture.runAsync(() -> readAttachment(uri, result));
    }

    private void readAttachment(Uri uri, MethodChannel.Result result) {
        ContentResolver resolver = getContentResolver();
        Map<String, Object> attachment = new HashMap<>();
        try (Cursor cursor = resolver.query(uri, new String[] {OpenableColumns.DISPLAY_NAME},
                null, null, null);
                InputStream stream = resolver.openInputStream(uri)) {
            if (cursor == null || !cursor.moveToFirst() || stream == null) {
                throw new IOException("No readable document or metadata.");
            }
            String name = cursor.getString(0);
            if (name == null || name.isEmpty()) {
                throw new IOException("No display name.");
            }
            String mimeType = resolver.getType(uri);
            attachment.put("name", name);
            attachment.put("mimeType", mimeType == null ? "application/octet-stream" : mimeType);
            attachment.put("bytes", readBounded(stream));
        } catch (AttachmentTooLarge e) {
            finishAttachment(() -> result.error("too_large", "Attachment exceeds 2 MiB.", null));
            return;
        } catch (IOException | SecurityException e) {
            finishAttachment(() -> result.error("read_failed", "Could not read the selected attachment.", null));
            return;
        }
        finishAttachment(() -> result.success(attachment));
    }

    private static byte[] readBounded(InputStream stream) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int remaining = MAX_ATTACHMENT_BYTES;
        while (remaining > 0) {
            int count = stream.read(buffer, 0, Math.min(buffer.length, remaining));
            if (count == -1) {
                return bytes.toByteArray();
            }
            bytes.write(buffer, 0, count);
            remaining -= count;
        }
        if (stream.read() != -1) {
            throw new AttachmentTooLarge();
        }
        return bytes.toByteArray();
    }

    private static final class AttachmentTooLarge extends IOException {
    }

    private void finishAttachment(Runnable completion) {
        runOnUiThread(() -> {
            pendingAttachment = null;
            completion.run();
        });
    }
}
